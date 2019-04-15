# AzureStack-VolumesPerformanceDashboard-Generator
This tool is used to generate dashboard jsons showing volumes performance used on Azure Stack portal.
<img src="document/demo.png" />

### Feature
- User can specify time range by duration or startTime & endTime.
- User can specify eight types of time granularity. Default type is ‘Automatic’, which adapted to time range.
- Generate three json files representing count, latency and throughput performance.

### Usage
The script should run in Azure Stack environment:  
1. Extract files in attached zip.  
2. Log in AzureRm account.  
3. Import psm1 file. You can specify envName, adminSubscriptionName and jsonTemplateLocation in ArgumentList if needed.  
4. Execute function Save-AzureStackVolumesPerformanceDashboardJson with specified needed  parameters.  
	Or you can replace account username, password and ARMendpoint in testDashboardGenerator.ps1, then just one command to replace 2,3,4.  
	./ testDashboardGenerator.ps1  
5. Upload json generated on dashboard.  
