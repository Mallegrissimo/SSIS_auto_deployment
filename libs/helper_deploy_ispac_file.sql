use SSISDB;
go

Print 'SCRIPT: "deploySSIS.sql"';

DECLARE @ProjectBinary AS varbinary(max)
DECLARE @operation_id AS bigint
Declare @ispac_path as nvarchar(500);
Declare @folder_name as nvarchar(100);
Declare @project_name as nvarchar(100);
Declare @sql_str as nvarchar(1000);

set @ispac_path = '$(ispac_path)'; 
set @folder_name = '$(ssis_folder_name)'; 
set @project_name = '$(project_name)'; 

PRINT FORMATMESSAGE('folder:%s, project:%s, file:%s', @folder_name, @project_name, @ispac_path);

begin try
set @sql_str = Concat('SET @bin = (SELECT * FROM OPENROWSET(BULK ''', @ispac_path, ''', SINGLE_BLOB) AS BinaryData);');
exec sp_executesql @sql_str, N'@bin varbinary(max) out', @ProjectBinary out;

EXEC catalog.deploy_project @folder_name = @folder_name,
    @project_name = @project_name,
    @Project_Stream = @ProjectBinary,
    @operation_id = @operation_id out
;
end try
begin catch
	print space(5) + 'Failed to deploy: ' + FORMATMESSAGE('folder:%s, project:%s, file:%s', @folder_name, @project_name, @ispac_path) + ' in database ' + DB_NAME() + ' on server ' + @@SERVERNAME + '.  ' + Error_Message();
	RAISERROR(N'Failed to deploy package', 16, 1);
end catch
GO

Print 'END SCRIPT: "deploySSIS.sql"';
