################################################################################################################################
####### Author                        Date          Comment ####################################################################
####### Martin<Martin.job8@gmail.com  24/6/2019     initial
################################################################################################################################
################################################################################################################################
# This contains functions used internally by the deployment process.
# This file should not be edited as part of the deployment.

function format_ssis_var_value
{
	param( [string]$value, [string]$type )
	if ($type -eq 'string') 
		{"N'" + $value + "'"}
	else {$value}
}


function create_ssis_env_vars {
	foreach ($var_details in $ssis_env_vars) {
		$value_formatted = format_ssis_var_value $var_details.var_value $var_details.var_type
		$sql_str = "exec deploy_ssis_env_var  " `
			+ "  @var_name         = N'" + $var_details.var_name			+ "'" `
			+ ", @var_description  = N'" + $var_details.var_description		+ "'" `
			+ ", @ssis_env_name    = N'" + $ssis_env_name					+ "'" `
			+ ", @ssis_folder_name = N'" + $ssis_folder_name				+ "'" `
			+ ", @var_value        = "   + $value_formatted                       `
			+ ", @var_type         = N'" + $var_details.var_type			+ "'" 
        
		Write-Host $($MyInvocation.MyCommand.Name) ": sql_str[" $sql_str ']'
		Invoke-Sqlcmd -verbose -AbortOnError -ServerInstance $ssis_srvr -Database $ssis_dbname -Query $sql_str
	}
}

function link_params_to_env_vars {
	foreach ($package_param in $package_params) {
		$sql_str = "exec deploy_param_to_env_var  " `
			+ "  @object_name		= N'" + $package_param.object_name		+ "'" `
			+ ", @param_name		= N'" + $package_param.param_name		+ "'" `
			+ ", @folder_name   = N'" + $ssis_folder_name				+ "'" `
			+ ", @project_name 	= N'" + $ssis_project_name				+ "'" `
			+ ", @env_var_name  = N'" + $package_param.env_var_name     + "'" `

		Write-Host $($MyInvocation.MyCommand.Name) ": sql_str[" $sql_str ']'
		Invoke-Sqlcmd -verbose -AbortOnError -ServerInstance $ssis_srvr -Database $ssis_dbname -Query $sql_str
	}
}

function add_job_steps {
	$step_count = 0
	Write-Host $($MyInvocation.MyCommand.Name) ":Found " $job_steps.Length  " steps"
	foreach ($job_step in $job_steps) {
		$step_count = $step_count + 1
		$sql_str = "exec deploy_add_job_step  " `
			+ "  @job_name			= N'" + $job_name						+ "'" `
			+ ", @step_count		= "   + $step_count		                      `
			+ ", @num_steps     = "   + $job_steps.Length			          `
			+ ", @ssis_dbname		= N'" + $ssis_dbname					+ "'" `
			+ ", @ssis_folder_name  = N'" + $ssis_folder_name				+ "'" `
			+ ", @ssis_project_name	= N'" + $ssis_project_name				+ "'" `
			+ ", @package_name     	= N'" + $job_step.package_name     		+ "'" `
			+ ", @ssis_srvr			    = N'" + $ssis_srvr						+ "'" `
			+ ", @step_name     	  = N'" + $job_step.step_name     		+ "'" `
			+ ", @agent_proxy_name	= N'" + $agent_proxy_name				+ "'" `
			+ ", @ssis_env_name     = N'" + $ssis_env_name     		+ "'" 
		#Write-Host $($MyInvocation.MyCommand.Name) ": sql_str[" $sql_str ']'
		Invoke-Sqlcmd -verbose -AbortOnError -ServerInstance $ssis_srvr -Database $ssis_dbname -Query $sql_str
	}
	
	Write-Host $($MyInvocation.MyCommand.Name) ":Finished adding job steps."
}



function link_params_to_env_vars {
	foreach ($package_param in $package_params) {
		$sql_str = "exec deploy_param_to_env_var  " `
			+ "  @object_name		= N'" + $package_param.object_name		+ "'" `
			+ ", @param_name		= N'" + $package_param.param_name		+ "'" `
			+ ", @folder_name   = N'" + $ssis_folder_name				+ "'" `
			+ ", @project_name 	= N'" + $ssis_project_name				+ "'" `
			+ ", @env_var_name  = N'" + $package_param.env_var_name     + "'" `

		Invoke-Sqlcmd -verbose -AbortOnError -ServerInstance $ssis_srvr -Database $ssis_dbname -Query $sql_str
	}
}




function execute_sql_script([hashtable[]]$sql_script_configs,[string[]]$script_params){
	foreach ($asql in $sql_script_configs) {
		$afile  = $asql.script_file
		if (![System.IO.File]::Exists($afile)) { 
			$afile = $deployment_path + $asql.script_file
		}
        #Write-Host $($MyInvocation.MyCommand.Name) : -ServerInstance $asql.server -Database $asql.db_name -InputFile '[' $afile ']'
		#Write-Host "Variables:" $script_params 
		Invoke-Sqlcmd -verbose -AbortOnError -ServerInstance $asql.server    -Database $asql.db_name -InputFile $afile        -Variable $script_params	        
	}
}
