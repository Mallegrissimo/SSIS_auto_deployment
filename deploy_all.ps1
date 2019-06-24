
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

Write-Host $($MyInvocation.MyCommand.Name) ": Deploying database level ddl scripts"
execute_sql_script $database_sql_scripts 	$script_params
Write-Host $($MyInvocation.MyCommand.Name) ": Deploying database level ddl scripts....Done."

Write-Host $($MyInvocation.MyCommand.Name) ": Deploying application level ddl scripts"
execute_sql_script $app_sql_scripts 		$script_params
Write-Host $($MyInvocation.MyCommand.Name) ": Deploying application level ddl scripts....Done."

# Create the SSIS Environment and EnvVars
Write-Host $($MyInvocation.MyCommand.Name) ": Creating environment and Env Vars ssis_folder_name = " $ssis_folder_name "ssis_folder_description = " $ssis_folder_description
Write-Host $($MyInvocation.MyCommand.Name) ":"$script_params
Invoke-Sqlcmd -verbose -AbortOnError -ServerInstance $ssis_srvr -Database $ssis_dbname -InputFile $lib_path"helper_CreateEnv.sql" -Variable $script_params 
create_ssis_env_vars			#This is a function found in deploy_helper_functions.ps1.

# Deploy SSIS package
$ispac_path=$ispac_filename
Write-Host $($MyInvocation.MyCommand.Name) ": Deploying SSIS project from " $ispac_path
Invoke-Sqlcmd -verbose -AbortOnError -ServerInstance $ssis_srvr -Database $ssis_dbname  -InputFile $lib_path"helper_deploy_ispac_file.sql" -Variable $script_params 

# Link SSIS EnvVars to to the package params
Write-Host $($MyInvocation.MyCommand.Name) ": Linking Env Vars to SSIS project/package params"
Write-Host $($MyInvocation.MyCommand.Name) ": $script_params"
Invoke-Sqlcmd -verbose -AbortOnError -ServerInstance $ssis_srvr -Database $ssis_dbname -InputFile $lib_path"helper_linkEnvVars.sql" -Variable $script_params
link_params_to_env_vars			#This is a function found in deploy_helper_functions.ps1

# Create agent job
Invoke-Sqlcmd -verbose -AbortOnError -ServerInstance $ssis_srvr -Database $ssis_dbname -InputFile $lib_path"helper_sql_job.sql"
Write-Host $($MyInvocation.MyCommand.Name) ": Create Agent job"
Invoke-Sqlcmd -verbose -AbortOnError -ServerInstance $ssis_srvr -Database $ssis_dbname -InputFile $lib_path"CreateAgentJob.sql" -Variable $script_params
add_job_steps					#This is a function found in deploy_helper_functions.ps1
