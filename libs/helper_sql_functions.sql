PRINT 'SCRIPT:" all helper_sql_functions.sql"'


-------------helper_CreateEnv.sql
Declare @ssis_env_name			nvarchar(128);
Declare @ssis_env_description	nvarchar(1024);
Declare @env_id					bigint;
Declare @ssis_folder_name		nvarchar(128);
Declare @ssis_folder_description 	nvarchar(1024);

set @ssis_folder_name 			= '$(ssis_folder_name)'; 
set @ssis_env_name 				= '$(ssis_env_name)';
set @ssis_env_description 		= '$(ssis_env_description)';
set @ssis_folder_description 	= '$(ssis_folder_description)';

Print 'SCRIPT: "helper_CreateEnv.sql"';

-- create the folder
if not exists (select * from ssisdb.catalog.folders where name = @ssis_folder_name)
begin
	EXEC [SSISDB].[catalog].[create_folder] @folder_name=@ssis_folder_name
	EXEC [SSISDB].[catalog].[set_folder_description] @folder_name=@ssis_folder_name, @folder_description=@ssis_folder_description
	Print concat(space(5), 'Created the folder.')
end


-- create the environment
if not exists( select * from ssisdb.catalog.environments env inner join ssisdb.catalog.folders f on env.folder_id = f.folder_id
				where env.name = @ssis_env_name and f.name = @ssis_folder_name
)
begin
	EXEC [SSISDB].[catalog].[create_environment] @environment_name=@ssis_env_name, @environment_description=@ssis_env_description, @folder_name=@ssis_folder_name;
	Print concat(space(5), 'Created the environment.')
end
select @env_id = environment_id from ssisdb.catalog.environments where name = @ssis_env_name;

-- The following is called by the deploy script, function create_ssis_env_vars
if object_id('deploy_ssis_env_var', 'P') is not null drop procedure deploy_ssis_env_var;
go
create procedure deploy_ssis_env_var
	@var_name           nvarchar(128),
	@var_description    nvarchar(1024),
	@ssis_env_name      nvarchar(128),
	@ssis_folder_name   nvarchar(128),
	@var_value          sql_variant,
	@var_type           nvarchar(128)
as
begin
	declare @env_id 	bigint;
	Print concat(space(5), FORMATMESSAGE('Create or update SSIS env var:[%s].[%s].[%s] ', @ssis_folder_name, @ssis_env_name, @var_name));
	
	select @env_id = environment_id from ssisdb.catalog.environments env join ssisdb.catalog.folders f on env.folder_id= f.folder_id where f.name=@ssis_folder_name and env.name = @ssis_env_name;
	if not exists(select * from ssisdb.catalog.environment_variables where environment_id = @env_id and name = @var_name)
	begin
		EXEC [SSISDB].[catalog].[create_environment_variable] @variable_name=@var_name, @sensitive=False, @description=@var_description, @environment_name=@ssis_env_name, @folder_name=@ssis_folder_name, @value=@var_value, @data_type=@var_type;
		Print concat(space(10), 'Created SSIS env var:', @var_name);
	end
	else
	begin
		EXEC [SSISDB].[catalog].[set_environment_variable_value ] @folder_name = @ssis_folder_name, @environment_name = @ssis_env_name, @variable_name=@var_name, @value=@var_value;
		Print concat(space(10), 'Updated SSIS env var:', @var_name);
	end;
end;

Print 'SCRIPT: "End of helper_CreateEnv.sql"';
go


Declare @reference_id		bigint;
Declare @project_id			bigint;

--set @ssis_folder_name 			= '$(ssis_folder_name)'; 
--set @ssis_env_name 				= '$(ssis_env_name)';

PRINT FORMATMESSAGE('Linking variables for:Env:%s, Folder:%s, Project:%s', @ssis_env_name, @ssis_folder_name, @project_name);
-- Link the project to the environment
select @project_id = project_id from ssisdb.catalog.projects prj join ssisdb.catalog.folders f on f.folder_id = prj.folder_id where f.name=@ssis_folder_name and prj.name = @project_name ;
if not exists (select * from ssisdb.catalog.environment_references where environment_name = @ssis_env_name and project_id = @project_id)
begin
	EXEC [SSISDB].[catalog].[create_environment_reference] @environment_name=@ssis_env_name, @reference_id=@reference_id OUTPUT, @project_name=@project_name, @folder_name=@ssis_folder_name, @reference_type=R;
	Print concat(space(5), 'Reference created.')
end
ELSE
	Print concat(space(5), 'Reference already exists.');


-- This is called by the deploy script, function link_param_to_env_var
if object_id('link_param_to_env_var', 'P') is not null drop procedure link_param_to_env_var;
go
create procedure link_param_to_env_var
	@object_name		nvarchar(128),
	@param_name			nvarchar(128),
	@folder_name		nvarchar(128),
	@project_name		nvarchar(128),
	@env_var_name		nvarchar(128)
as
Begin
	declare @object_type int = 30
	select @object_type = object_type
			from ssisdb.catalog.projects prj
			join ssisdb.catalog.folders f on prj.folder_id= f.folder_id
			join ssisdb.catalog.object_parameters p on prj.project_id = p.project_id
			where prj.name=@project_name and f.name=@folder_name and parameter_name=@param_name
		
	if not exists (select referenced_variable_name from ssisdb.catalog.object_parameters where object_name = @param_name and parameter_name = @param_name and referenced_variable_name is not null)
	begin
		--PRINT FORMATMESSAGE('object_type:%s,@parameter_name=%s, @object_name=%s, @folder_name=%s, @project_name=%s, @value_type=R, @parameter_value=%s', @env_var_name,@param_name,@object_name,@folder_name,@project_name,@env_var_name);--,, \\\@object_type,@param_name,@object_name,@folder_name,@project_name,@env_var_name);
		EXEC [SSISDB].[catalog].[set_object_parameter_value] @object_type=@object_type, @parameter_name=@param_name, @object_name=@object_name, @folder_name=@folder_name, @project_name=@project_name, @value_type=R, @parameter_value=@env_var_name;
		Print concat(space(5), 'linked param ', @object_name, '::', @param_name, ' to ', @env_var_name);
	end;
end;
go


Print concat(space(10), 'END SCRIPT: "helper_LinkEnvVars.sql"');




go

Print 'SCRIPT: "helper_sql_functions.sql"';

if object_id('vw_agent_packages', 'V') is null
Begin
	Declare @create_dummy nvarchar(1000);
	set @create_dummy = 'create view vw_agent_packages as select 1 as dummy_col';
	exec(@create_dummy);
	print concat(space(5), 'Created view vw_agent_packages.');
End
ELSE
	print concat(space(5), 'Failed to create view vw_agent_packages.  View already exists.');
;

go
alter view vw_agent_packages  as
SELECT  
	PackagePathName = FORMATMESSAGE('\SSISDB\%s\%s\%s', F2.name, PJ.name, PK.name),
	EnvironnmentPathName = FORMATMESSAGE('\SSISDB\%s\%s', F.name, E.name),
	EnvironmentReferenceID = ER.reference_id,
	ProjectFolder = F.name,
	Project = PJ.name,
	Package = PK.name,
	EnvironmentFolder = F2.name,
	Environment = E.name
FROM    catalog.folders AS F
	INNER JOIN catalog.environments AS E ON E.folder_id = F.folder_id
	INNER JOIN catalog.environment_references AS ER ON (ER.reference_type = 'A'
			AND ER.environment_folder_name = F.name
			AND ER.environment_name = E.name)
		OR (ER.reference_type = 'R'
			AND ER.environment_name = E.name)
	INNER JOIN catalog.projects AS PJ ON PJ.project_id = ER.project_id
	INNER JOIN catalog.packages AS PK ON PK.project_id = PJ.project_id
	INNER JOIN catalog.folders AS F2 ON F2.folder_id = PJ.folder_id
;
go
print concat(space(5), 'Altered view vw_agent_packages.');





print concat(space(5), 'creating helper stored procedure: deploy_add_job_step.');
-- This is called by the powershell deploy script, function add_job_steps
if object_id('deploy_add_job_step', 'P') is not null drop procedure deploy_add_job_step;
go
create procedure deploy_add_job_step
	@job_name				nvarchar(100),
	@step_count				int,
	@num_steps				int,
	@ssis_dbname			nvarchar(100),
	@ssis_folder_name		nvarchar(100),
	@ssis_project_name		nvarchar(100),
	@package_name			nvarchar(100),
	@ssis_srvr				nvarchar(100),
	@step_name				nvarchar(100),
	@agent_proxy_name		nvarchar(100),
	@ssis_env_name			nvarchar(100)
as
begin  
declare @on_success_action  int;  
declare @env_ref_id      int;  
declare @command    nvarchar(2000);  
declare @jobId     BINARY(16);  
declare @package_path   nvarchar(1000);  
declare @ReturnCode    INT;  
  
 -- set @step_count = @step_count + 1;  
 if @step_count >= @num_steps   
 begin  
  print concat(space(5) , 'Adding last step to job.');
  set @on_success_action = 1;  
 end  
 else  
 begin  
  Print concat(space(5) , 'Adding step ' , cast(@step_count as varchar(10)) , ' "' , @step_name , '" to job.');
  set @on_success_action = 3;  
 end;  
   
 select @jobId = job_id from msdb.dbo.sysjobs where name = @job_name;  
       
 set @package_path = FORMATMESSAGE('\%s\%s\%s\%s',@ssis_dbname,@ssis_folder_name,@ssis_project_name,@package_name);  
   
 select @env_ref_id = EnvironmentReferenceID from vw_agent_packages where PackagePathName = @package_path and ProjectFolder=@ssis_folder_name and Environment = @ssis_env_name;  
   
 set @command = FORMATMESSAGE(N'/ISSERVER "\"\%s\%s\%s\%s\"" /SERVER "\"%s\"" /ENVREFERENCE %i /Par "\"$ServerOption::LOGGING_LEVEL(Int16)\"";1 /Par "\"$ServerOption::SYNCHRONIZED(Boolean)\"";True /CALLERINFO SQLAGENT /REPORTING E',  
  @ssis_dbname,  
  @ssis_folder_name,  
  @ssis_project_name,  
  @package_name,  
  @ssis_srvr  
  ,@env_ref_id  
 );  
 --Print @command;  
  
 EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId,   
  @step_name=@step_name,   
  @step_id=@step_count,   
  @cmdexec_success_code=0,   
  @on_success_action=@on_success_action,   
  @on_success_step_id=0,   
  @on_fail_action=2,   
  @on_fail_step_id=0,   
  @retry_attempts=0,   
  @retry_interval=0,   
  @os_run_priority=0, @subsystem=N'SSIS',   
  @command=@command,  
  @database_name=N'master',   
  @flags=0,   
  @proxy_name=@agent_proxy_name  
  
     Print concat(space(5) , 'Added step ' , cast(@step_count as varchar(10)) , ' "' , @step_name , '" to job.');
 ;  
end;  
go
print concat(space(5), 'created helper stored procedure: deploy_add_job_step.');

PRINT 'END SCRIPT:" helper_sql_functions.sql"'
