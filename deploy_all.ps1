################################################################################################################################
####### Author                         Date          Comment ####################################################################
####### Martin<Martin.job8@gmail.com>  24/6/2019     initial
################################################################################################################################
################################################################################################################################

$lib_path = "$PSScriptRoot/libs/"
$config_path = "$PSScriptRoot/configs/"
$deployment_path = "$PSScriptRoot/Deployment/"

#load function and configurations before actual start
. $lib_path"deploy_helper_functions.ps1" #helper functions
. ./deploy_env_config.ps1                #environment config
. $config_path"deploy_vars_config.ps1"   #sql scripts & environment mappings etc
. $config_path"deploy_sql_script_var_config.ps1" #variables required for sql scripts for Invoke-Sqlcmd


Write-Host $($MyInvocation.MyCommand.Name) "Staging db:[$Staging_db_name]"
Write-Host $($MyInvocation.MyCommand.Name) ": Deploying change set for [$app_name] to [$env_name]"
$confirmation = Read-Host "Are you sure you want to proceed:[y/n]"
while($confirmation -ne "y")
{
    if ($confirmation -eq 'n') {exit}
    $confirmation = Read-Host "Ready? [y/n]"
}

Write-Host "********* Rename file deploy_env_config_$env_name.ps1 to deploy_env_config.ps1   ************"
$confirmation = Read-Host "Confirm above configuration is ready, Are you sure you want to proceed:[y/n]"
while($confirmation -ne "y")
{
    if ($confirmation -eq 'n') {exit}
    $confirmation = Read-Host "Ready? [y/n]"
}

#prepare for sql scripts
$script_params = $config_sql_script_params

#5~8 deploy ddl/dml scripts
	Write-Host $($MyInvocation.MyCommand.Name) ": Deploying database level ddl scripts"
	execute_sql_script $database_sql_scripts 	$script_params
	Write-Host $($MyInvocation.MyCommand.Name) ": Deploying database level ddl scripts....Done."

	Write-Host $($MyInvocation.MyCommand.Name) ": Deploying application level ddl scripts"
	execute_sql_script $app_sql_scripts 		$script_params
	Write-Host $($MyInvocation.MyCommand.Name) ": Deploying application level ddl scripts....Done."

# deploy helper_sql_functions.sql
	Write-Host $($MyInvocation.MyCommand.Name) ": deploy helper_sql_functions.sql"
	Invoke-Sqlcmd -verbose -AbortOnError -ServerInstance $ssis_server -Database $ssis_dbname -InputFile $lib_path"helper_sql_functions.sql" -Variable $script_params 

#9 deploy sql script to set up SSIS environment and create variables
	Write-Host $($MyInvocation.MyCommand.Name) ": Creating environment and Env Vars ssis_folder_name = " $ssis_folder_name "ssis_folder_description = " $ssis_folder_description
	create_ssis_env_vars			#This is a function found in deploy_helper_functions.ps1.

#10 deploy ISPAC file
	$ispac_path=$ispac_filename
	Write-Host $($MyInvocation.MyCommand.Name) ": Deploying SSIS project from " $ispac_path
	Invoke-Sqlcmd -verbose -AbortOnError -ServerInstance $ssis_server -Database $ssis_dbname  -InputFile $lib_path"helper_deploy_ispac_file.sql" -Variable $script_params 

#11 Link SSIS EnvVars to to the package params
	Write-Host $($MyInvocation.MyCommand.Name) ": Linking Env Vars to SSIS project/package params"
	link_params_to_env_vars			#This is a function found in deploy_helper_functions.ps1

#12 Create agent job
	Write-Host $($MyInvocation.MyCommand.Name) ": Create Agent job"
	Invoke-Sqlcmd -verbose -AbortOnError -ServerInstance $ssis_srvr -Database $ssis_dbname -InputFile $lib_path"CreateAgentJob.sql" -Variable $script_params
	add_job_steps					#This is a function found in deploy_helper_functions.ps1

