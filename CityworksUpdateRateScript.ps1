<# 
    Cityworks Rates PowerShell Script
    Colby Schrupp & Ryan
    10/24/2024

    This script retrieves employee rates from Naviline and imports them into Cityworks. 
    It checks for each employee ID in both systems to ensure it matches. If the Employee ID 
    is valid, the script then determines whether the employee is full-time or part-time,
    and adds their current rate, benefit percentage, overtime rate, and holiday rate accordingly.
#>

# Cityworks Server URL
[string]$BaseURL = "URL of Cityworks Site"

# Cityworks Authenication Inforamtion
$CWTValue = Invoke-RestMethod -Uri "$BaseURL/services/General/Authentication/Authenticate?data={'LoginName':'','Password':''}"| Select-Object -ExpandProperty Value
$CWToken = Write-Output $CWTValue|Select-Object -ExpandProperty Token

# Gathers All Employee Inforamtion From Cityworks
$employees = Invoke-restmethod -URI "$BaseURL/services/Ams/Employee/All?data={'IncludeInactive':'false'}&token=$CWToken" | Select-Object -ExpandProperty Value


# Finds each employee in Naviline that is in Cityworks.
foreach($employee in $employees){

# Pulls Cityworks Employee Information and Assigns it to a variable.
$First = $employee.FirstName
$Last = $employee.LastName
$CWeeid = $employee.EmployeeId
$CWSID = $employee.EmployeeSid

# Naviline API Call
$NavEmployees = @{
    Uri = "Naviline URL"
    Headers = @{"X-APPID" = ""; "X-APPKEY" = ""}
    Method = "POST"
    ContentType = "application/x-www-form-urlencoded"
    Body = @{"ssn" = ""}
}
# Finds Employees based on first name, last name, and Employee ID
$Query = Invoke-RestMethod @NavEmployees|Select-Object -ExpandProperty Rows|Where-Object -Property eeid -EQ $CWeeid

# Gets the employee schedule type from Naviline
$ScheduleType = $Query.BARUNIT

<# 
   Convert annual rate and converts it into hourly rate. 
   Benefit, Overtime, and Holiday rates are set based on Payroll.
   Employee ID also comes from Naviline
#>
if ($ScheduleType -eq "REGULAR FULL TIME" -or $ScheduleType -eq "FIRE UNION" -or $ScheduleType -eq "POLICE UNION" ){
    $Rate = $Query.SALARY / 2080
    $Benefit = 21.65
    $OT = 150
    $Holiday = 200
    $eeid = $Query.eeid
} elseif ($ScheduleType -eq "REGULAR PART-TIME" -or $ScheduleType -eq "TEMPORARY" -or $ScheduleType -eq "SEASONAL EMPLOYEE"){
    $Rate = $Query.SALARY / 1040
    $Benefit = 0
    $OT = 0
    $Holiday = 0
    $eeid = $Query.eeid
} else {
    Write-Host "Schedule type is unkown."
}
 
# Rounds the employee rate to the second decimal place.
$RateRound = [math]::Round($Rate,2)


# Gets Cityworks hourly rate and assigns it to cwrate 
$cwrate = $employee.HourlyRate

Write-Host "$First $Last"
$Rate
$RateRound
$Benefit
$OT
$Holiday
$eeid
$cwrate
Write-Host "--------------`n"

# Updates the employeee's cityworks rates if the employee's value is higher in Naviline.
if($RateRound -gt $cwrate){
    $EmployeeUpdate = "$BaseURL/services/Ams/Employee/Update?data={'EmployeeSids':['$CWSID'],'HourlyRate':'$RateRound','BenefitRate':'$Benefit','OvertimeRate':'$OT','HolidayRate':'$Holiday'}&Token=$CWToken"
    Invoke-RestMethod -Uri $EmployeeUpdate -Method Post
} elseif ($RateRound -eq $cwrate) {
    Write-Host "Naviline rate is equal to Cityworks!"
} elseif ($RateRound -lt $cwrate) {
    Write-Host "Cityworks is HIGHER than Naviline!"
} else {
    Write-Host "An error has occurred"
}

#Clear Cityworks employee ID
$CWeeid = $null
$Rate = $null
$RateRound = $null
$Benefit = $null
$OT = $null
$Holiday = $null
$eeid = $null
$cwrate = $null

}