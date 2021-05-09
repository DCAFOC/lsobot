<# 
////////////////////////////////////////////// LSO BOT //////////////////////////////////////////////

Version: 1.1.0 dev

Join the Discord: https://discord.gg/nr9xb6YJfw

Contributors:
YoloWingPixie   | https://github.com/YoloWingPixie
Auranis         | https://github.com/Auranis

Special Thanks to:
Carrier Strike Group 8 - https://discord.gg/9h9QUA8

#>
param(
    $LsoScriptRoot
)

    # BEGIN FUNCTIONS

    function Get-Timestamp {
        return Get-Date -Format "yyyy-MM-dd HH:mm:ss:fff"
    }

# END FUNCTIONS

    $debugLog = "$LsoScriptRoot\Logs\lsoBot-debug.txt"
    $rawGradelog = "$LsoScriptRoot\Logs\lsoBot-rawGrades.txt"
    $configPath = "$LsoScriptRoot\LsoBot-Config.psd1"

    Write-Output "$(Get-Timestamp) $logInfo LSO BOT Job Started" | Out-file $debugLog -append
    #Import the configuration file

    Get-Content $configPath
    $lsoConfig = Import-PowerShellDataFile $configPath

    Write-Output "$(Get-Timestamp) $logInfo Successfully imported config file" | Out-file $debugLog -append

    $dcsLogPath = $lsoConfig.logpath

    #Replace the environment variable USERPROFILE with the path.
    if ($dcsLogPath -match '\$env:USERPROFILE') {
        $dcsLogPath = $dcsLogPath -replace '\$env:USERPROFILE', $env:USERPROFILE
    }



#General Variables

$logInfo = " | INFO | "
$logWarning = " | WARNING | "
$logError = " | ERROR | "
$logRegex = " | REGEX | "
$logDiscord = " | DISCORD | "

# The regex to check the log messages for
$lsoEventRegex = "^.*landing.quality.mark.*"

# The regex to check log messages for takeoff events to detect bolters
$takeoffEventRegex = "^.*takeoff.*$"

<# 
    $lsoStartTime : The time the job started
    $lsoJobSpan : The time the job should run for, which should equal the repetition interval of the scheudled job trigger
    $lsoStopTime : The time the job should stop which is $lsoStartTime + $lsoJobSpan
    $timeTarget : This is the integer that will be fed to the for loop to exit the loop once the job has reached $lsoStopTime
    $scanInterval : This timespawn represents the default time span that the main loop will sleep for. This is modified heavily in the loop, do not modify without understanding the code.
    $lsoBolterSleepTimer : The amount of time that the loop should sleep if it detects a potential Bolter, to catch the takeoff event in the log.
#>

[DateTime]$lsoStartTime = [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff')
$lsoJobSpan = New-TimeSpan -Seconds 60
[DateTime]$lsoStopTime = $lsoStartTime + $lsoJobSpan
$scanInterval = New-TimeSpan -Seconds 15
$timeTarget = $lsoJobSpan.TotalSeconds/$scanInterval.TotalSeconds
$lsoBolterSleepTimer = New-TimeSpan -Seconds 6


Write-Output "$(Get-Timestamp) $logInfo scan interval is $scanInterval" | Out-file $debugLog -append
Write-Output "$(Get-Timestamp) $logInfo time target is $timeTarget" | Out-file $debugLog -append

#Garbage Collection
[system.gc]::Collect()


# /////////////////////////////////////////////////////////////////////

# BEGIN REGRADING REGEX

#Grade Regex
$1WIRE =     "(?:WIRE# 1)"
$WIRE =     "(?:WIRE# \d{1})"
$PERFECT =  '_OK_ (Perfect): '
$OK =       'OK (Acceptable): '
$FAIR =     '(OK) (Fair): '
$NOGRADE =  '--- (No Grade): '
$CUT =      'C (CUT): '
$WO =       'WO (Wave Off): '
$OWO =      'OWO (Own Wave Off): '
$BOLTER =   'GRADE: B (Bolter)'
$WOAFU =    "WO\(AFU\)(IC|AR|IM)"
$WOAFUTL =  "WO\(AFU\)TL"
$rWO =      "GRADE:WO"
$rOWO =     "GRADE:OWO"
$rGRADE =   "GRADE:\S{1,3}"

#Grade Remarks Regex - Removals
$SLOX = "(_|\()?(?:SLOX)(_|\))?"
$EGIW = "(_|\()?(?:EGIW)(_|\))?"
$BC = "(?:\[BC\])"

# Left and Right positions, no minor deviations
$LEFT = "(?!\))_?D?L?U?L(X|IM|IC|AR)_?(?!\))"
$RIGHT = "(?!\))_?D?L?U?R(X|IM|IC|AR)_?(?!\))"


# (X) At Start
$LULX =     "(_|\()?(?:LULX)(_|\))?"
$LURX =     "(_|\()?(?:LURX)(\)|_)?"
$HX =       "(_|\()?(?:HX)(_|\))?"
$LOX =      "(_|\()?(?:LOX)(_|\))?"
$FX =       "(_|\()?(?:FX)(_|\))?"
$NX =       "(_|\()?(?:NX)(_|\))?"
$WX =       "(_|\()?(?:WX)(_|\))?"
$DRX =      "(_|\()?(?:DRX)(_|\))?"
$DLX =      "(_|\()?(?:DLX)(_|\))?"

# (IM) In Middle
$LURIM =    "(_|\()?(?:LURIM)(_|\))?"
$LULIM =    "(_|\()?(?:LULIM)(_|\))?"
$HIM =      "(_|\()?(?:HIM)(_|\))?"
$LOIM =     "(_|\()?(?:LOIM)(_|\))?"
$DRIM =     "(_|\()?(?:DRIM)(_|\))?"
$DLIM =     "(_|\()?(?:DLIM)(_|\))?"
$FIM =      "(_|\()?(?:FIM)(_|\))?"
$SLOIM =    "(_|\()?(?:SLOIM)(_|\))?"
$WIM =      "(_|\()?(?:WIM)(_|\))?"
$TMRDIM =   "(_|\()?(?:TMRDIM)(_|\))?"
$NERDIM =   "(_|\()?(?:NERDIM)(_|\))?"

# (IC) In Close
$LURIC =    "(_|\()?(?:LURIC)(_|\))?"
$LULIC =    "(_|\()?(?:LULIC)(_|\))?"
$LOIC =     "(_|\()?(?:LOIC)(_|\))?"
$HIC =      "(_|\()?(?:HIC)(_|\))?"
$FIC =      "(_|\()?(?:FIC)(_|\))?"
$PIC =      "(?<!PP)(_|\()?(?:PIC)(_|\))"
$PPPIC =    "(_|\()?(?:PPPIC)(_|\))?"
$WIC =      "(_|\()?(?:WIC)(_|\))?"
$DRIC =     "(_|\()?(?:DRIC)(_|\))?"
$DLIC =     "(_|\()?(?:DLIC)(_|\))?"
$NERDIC =   "(_|\()?(?:NERDIC)(_|\))?"
$TMRDIC =   "(_|\()?(?:TMRDIC)(_|\))?"
$SLOIC =    "(_|\()?(?:SLOIC)(_|\))?"


# (AR) At Ramp
$LURAR =    "(_|\()?(?:LURAR)(_|\))?"
$LULAR =    "(_|\()?(?:LULAR)(_|\))?"
$LOAR =     "(_|\()?(?:LOAR)(_|\))?"
$HAR =      "(_|\()?(?:HAR)(_|\))?"
$FAR =      "(_|\()?(?:FAR)(_|\))?"
$SLOAR =    "(_|\()?(?:SLOAR)(_|\))?"
$PAR =      "(_|\()?(?:PAR)(_|\))?"
$WAR =      "(_|\()?(?:WAR)(_|\))?"
$DRAR =     "(_|\()?(?:DRAR)(_|\))?"
$DLAR =     "(_|\()?(?:DLAR)(_|\))?"
$NERDAR =   "(_|\()?(?:NERDAR)(_|\))?"
$TMRDAR =   "(_|\()?(?:TMRDAR)(_|\))?"

# (IW) In Wires
$LURIW =    "(_|\()?(?:LURIW)(_|\))?"
$LULIW =    "(_|\()?(?:LULIW)(_|\))?"
$LOIW =     "(_|\()?(?:LOIW)(_|\))?"
$SLOIW =    "(_|\()?(?:SLOIW)(_|\))?"
$FIW =      "(_|\()?(?:FIW)(_|\))?"
$LLIW =     "(_|\()?(?:LLIW)(_|\))?"
$LRIW =     "(_|\()?(?:LRIW)(_|\))?"
$3PTSIW =   "(_|\()?(?:3PTSIW)(_|\))?"
$BIW =      "(_|\()?(?:BIW)(_|\))?"
$EGTL =     "(_|\()?(?:EGTL)(_|\))?"

# END REGRADING REGEX

# ////////////////////////////////// MAIN LOOP STARTS HERE //////////////////////////////////

for ($i = 1; $i -le $timeTarget; $i++) {

    Write-Output "$(Get-Timestamp) $logInfo Begin cycle $i of $timeTarget" | Out-file $debugLog -append

    #Get the system time, convert to UTC, and format to HH:mm:ss. We need this for the DCS log.
    [DateTime]$lsoLoopUtcTime = [DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss.fff')

    #Get the system time in localized time for Loop duration tracking.
    [DateTime]$lsoLoopStartSysTime = [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff')

    #Has the job run it's course? If so, stop.
    if ($lsoLoopStartSysTime -ge $lsoStopTime ) {

        Write-Output "$(Get-Timestamp) $logInfo LSO BOT Job Ending" | Out-file $debugLog -append
        Exit
    
    }
    # Is the loop duration null? (This happens on Run 0 of the job), set it to a fair 150ms.
    if ($lsoLoopDuration -eq $null) {
        $lsoLoopDuration = New-TimeSpan -Milliseconds 150
    }

    #Calculate the scan interval. To make a long story short, there is a small couple hundred millisecond gap between when the last job cycle opens the dcs.log and when it completes.
    #On top of that, DCS doesn't post landings instantaneously to the log.
    #So there exists a roughly 300ms gap that a landing can occur in that will be skipped by LSO BOT if you don't account for these dead zones.
    #The calculations down below, add in the run duration of the previous loop multiplied by two to compensate for this. 
    #If a bolter was detected on the previous cycle, the minimum runtime of the loop is 6000ms due to the wait time. We test for that first, and subtract out the BolterSleepTimer.

    $scanInterval = New-TimeSpan -Seconds 15
    if ($lsoLoopDuration.TotalMilliseconds -gt $lsoBolterSleepTimer.TotalMilliseconds) {
        $scanInterval =  $scanInterval + ($lsoLoopDuration - $lsoBolterSleepTimer) + ($lsoLoopDuration - $lsoBolterSleepTimer)       
    }
    else {
        $scanInterval = $scanInterval + $lsoLoopDuration + $lsoLoopDuration
    }

    #Reset Bolter control
    $lsoNoBolter = 0


    #Check dcs.log for the last line that matches the landing quality mark regex.
    try {

        $landingEvent = Select-String -Path $dcsLogPath -Pattern $lsoEventRegex | Select-Object -Last 1

    }
    catch {

        Write-Output "$(Get-Timestamp) $logError Could not find dcs.log configured in $lsoConfig. Please check the file path configured in LsoBot.ps1." | Out-file $debugLog -append

    }   

    #If dcs.log did not contain any lines that matched the LSO regex, stop, otherwise continue

    if ($landingEvent -eq $null ) {

        Write-Output "$(Get-Timestamp) $logInfo No landing event detected" | Out-file $debugLog -append
        #Do Nothing
    }

    else {
        
    # Strip the log message down to the time that the log event occurred. 
    $logTime = $landingEvent
    $logTime = $logTime -replace "^.*(?:dcs\.log\:\d{1,5}\:)", ""
    $logTime = $logTime -replace "\..*$", ""
    #$logTime = $logTime.split()[-1]
    Write-Output "$(Get-Timestamp) $logInfo Trap detected at $logTime UTC" | Out-file $debugLog -append

    #Convert the log time string to a usable time object
    [DateTime]$trapTime = $logTime

    #Get the difference between the LSO event and the current time
    $diff = New-TimeSpan -Start $trapTime -End $lsoLoopUtcTime
    Write-Output "$(Get-Timestamp) $logInfo Time diference from the start of the loop is $diff" | Out-file $debugLog -append

    #Strip the log message down to the pilot name
    $Pilot = $landingEvent
    $Pilot = $Pilot -replace "^.*(?:initiatorPilotName=)", ""
    $Pilot = $Pilot -replace ",.*$", ""

    #Strip the log message down to the landing grade and add escapes for _
    $Grade = $landingEvent
    $Grade = $Grade -replace "^.*(?:comment=LSO:)", ""
    $Grade = $Grade -replace ",.*$", ""

                    Write-Output "$(Get-Timestamp) $logInfo Raw Grade is $Grade" | Out-file $debugLog -append

    <# 
    ---------------------------------------------------------------------
                            BEGIN REGRADING
    ---------------------------------------------------------------------
    #>


    <#        ////////////////////  REMOVALS    ////////////////////     #>

    # Remove SLOX, EGIW, and BC from vocab
    if ($Grade -match $SLOX ) {
        $Grade = $Grade -replace $SLOX, ""
        $Grade = $Grade -replace '\s+', ' '
        }
    if ($Grade -match $EGIW) {
        $Grade = $Grade -replace $EGIW, ""
        $Grade = $Grade -replace '\s+', ' '
        }
    if ($Grade -match $BC) {
        $Grade = $Grade -replace $BC, ""
        $Grade = $Grade -replace '\s+', ' '
        }

        $lockGrade = 0

    <#        ////////////////////  REPLACEMENTS    ////////////////////     #>

    #Find instances where DRX\DLX and LURX\LULX are called together, and replace with simply LURX\LULX
    if ((($Grade -match $DRX) -and ($Grade -match $LURX)) -or (($Grade -match $DLX) -and ($Grade -match $LULX))) {
        $Grade = $Grade -replace $DRX, ""
        $Grade = $Grade -replace $DLX, ""
        $Grade = $Grade -replace '\s+', ' '

    }

    #Find instances of _PIC_ _PPPIC_ and replace with _PPPIC_
    if (($Grade -match $PIC) -and ($Grade -match $PPPIC)) {
        $Grade = $Grade -replace $PIC, ""
        $Grade = $Grade -replace '\s+', ' '
    }

    #Find instances of DRX and DLX appearing in grade and replace with the one that appeared first. While technically possible, this is usually the LSO mistaking a late line up.
    if ($Grade -match -join($DRX, ".*", $DLX)) {
        $Grade = $Grade -replace $DLX, ""
        $Grade = $Grade -replace '\s+', ' '
        
    }
    if ($Grade -match -join($DLX, ".*", $DRX)) {
        $Grade = $Grade -replace $DRX, ""
        $Grade = $Grade -replace '\s+', ' '
    }

    #Find instances of LULX and LURX in grade and replace with the one that appeared first.
    if ($Grade -match -join($LURX, ".*", $LULX)) {
        $Grade = $Grade -replace $LULX, ""
        $Grade = $Grade -replace '\s+', ' '
        
    }
    if ($Grade -match -join($LULX, ".*", $LURX)) {
        $Grade = $Grade -replace $LURX, ""
        $Grade = $Grade -replace '\s+', ' '
    }

        $RawGrade = $Grade

    <#        ////////////////////  GRADING    ////////////////////     #>

    #Check for waveoffs

    # Check for WO(AFU)TL which should be a cut pass. These somtimes don't generate WIRE #
    if ($Grade -match $WOAFUTL) {
        Write-Output "$(Get-Timestamp) $logInfo $logRegex Found WO(AFU)TL, grading pass as Cut" | Out-file $debugLog -append
        $Grade = $Grade -replace $rGRADE, $CUT
        $Grade = $Grade -replace '\s+', ' '
        $lockGrade = 1
    }

    # Check for a WO(AFU)(IC|AR|IM) that still resulted in WIRE # in the grade, indicating a land, which should be a cut pass.

    if (($Grade -match $WOAFU) -and ($Grade -match $WIRE)) {
        Write-Output "$(Get-Timestamp) $logInfo $logRegex Found WO(AFU) and a WIRE caught, grading pass as Cut" | Out-file $debugLog -append
        $Grade = $Grade -replace $rGRADE, $CUT
        $Grade = $Grade -replace '\s+', ' '
        $lockGrade = 1
    }

    # Check for a Wave Off in the grade. If an WO is detected, get additional context from the log, look for a takeoff event from the same player that was landing.
    #If the $Pilot has taken off from the boat within 7 secounds of the grade, presume this is a bolter.
    if ($Grade -match $rWO) {
        Write-Output "$(Get-Timestamp) $logInfo $logRegex Found a wave off. Sleeping for 6 seconds to detect a bolter" | Out-file $debugLog -append
        Start-Sleep -Seconds $lsoBolterSleepTimer.TotalSeconds
        $getLandingContext = Select-String -Path $dcsLogPath -Pattern $lsoEventRegex -Context 12 | Select-Object -Last 1 | Out-String
        $getLandingContext = $getLandingContext -Split "`r`n"
        if ($getLandingContext -match $takeoffEventRegex) {
            Write-Output "$(Get-Timestamp) $logInfo $logRegex Found a takeoff event within bolter timeframe." | Out-file $debugLog -append
            $getTakeoffEventPilot = Select-String -Path $dcsLogPath -Pattern $takeoffEventRegex | Select-Object -Last 1
            $getTakeoffEventPilot = $getTakeoffEventPilot -replace "^.*(?:takeoff,initiatorPilotName=)", ""
            $getTakeoffEventPilot = $getTakeoffEventPilot -replace ",.*$", ""
            $getTakeoffEventTime = Select-String -Path $dcsLogPath -Pattern $takeoffEventTimeRegex | Select-Object Matches -Last 1
                if ($getTakeoffEventTime.Matches.Value -le $trapTime+7) {
                    Write-Output "$(Get-Timestamp) $logInfo $logRegex Detected bolter, grading pass as Bolter" | Out-file $debugLog -append
                        $Grade = $Grade -replace $rGRADE, $BOLTER
                        $Grade = $Grade -replace '\s+', ' '
                        $lockGrade = 1  
                    }                
                else {
                    Write-Output "$(Get-Timestamp) $logInfo $logRegex Did not detect bolter, grading pass as WO" | Out-file $debugLog -append
                    $Grade = $Grade -replace $rGRADE, $WO
                    $Grade = $Grade -replace '\s+', ' '
                    $lockGrade = 1
                    }
                }
                else {
                    Write-Output "$(Get-Timestamp) $logInfo $logRegex Did not detect bolter, grading pass as WO" | Out-file $debugLog -append
                    $Grade = $Grade -replace $rGRADE, $WO
                    $Grade = $Grade -replace '\s+', ' '
                    $lsoNoBolter = 1
                    $lockGrade = 1
                }
            }




    #Check for an Own Wave Off in the grade. If an own wave off is detected, get additional context from the log, look for a takeoff event from the same player that was landing.
    #If the $Pilot has taken off from the boat within 7 secounds of the grade, presume this is a bolter.
    if($lockGrade -eq 0){
        if ($Grade -match $rOWO) {
            Write-Output "$(Get-Timestamp) $logInfo $logRegex Found an own wave off. Sleeping for 6 seconds to detect a bolter" | Out-file $debugLog -append
            Start-Sleep -Seconds $lsoBolterSleepTimer.TotalSeconds
            $getLandingContext = Select-String -Path $dcsLogPath -Pattern $lsoEventRegex -Context 12 | Select-Object -Last 1 | Out-String
            $getLandingContext = $getLandingContext -Split "`r`n"
            if ($getLandingContext -match $takeoffEventRegex) {
                Write-Output "$(Get-Timestamp) $logInfo $logRegex Found a takeoff event within bolter timeframe." | Out-file $debugLog -append
                $getTakeoffEventPilot = Select-String -Path $dcsLogPath -Pattern $takeoffEventRegex | Select-Object -Last 1
                $getTakeoffEventPilot = $getTakeoffEventPilot -replace "^.*(?:takeoff,initiatorPilotName=)", ""
                $getTakeoffEventPilot = $getTakeoffEventPilot -replace ",.*$", ""
                $getTakeoffEventTime = Select-String -Path $dcsLogPath -Pattern $takeoffEventTimeRegex | Select-Object Matches -Last 1
                    if ($getTakeoffEventTime.Matches.Value -le $trapTime+7) {
                            Write-Output "$(Get-Timestamp) $logInfo $logRegex Detected bolter, grading pass as Bolter" | Out-file $debugLog -append
                            $Grade = $Grade -replace $rGRADE, $BOLTER
                            $Grade = $Grade -replace '\s+', ' '
                            $lockGrade = 1  
                            }
                    else {
                        Write-Output "$(Get-Timestamp) $logInfo $logRegex Did not detect bolter, grading pass as OWO" | Out-file $debugLog -append
                        $Grade = $Grade -replace $rGRADE, $OWO
                        $Grade = $Grade -replace '\s+', ' '
                        $lockGrade = 1       
                        }
                    }
                else {
                    Write-Output "$(Get-Timestamp) $logInfo $logRegex Did not detect bolter, grading pass as WO" | Out-file $debugLog -append
                    $Grade = $Grade -replace $rGRADE, $OWO
                    $Grade = $Grade -replace '\s+', ' '
                    $lsoNoBolter = 1
                    $lockGrade = 1
                    }
                }
            }

    

    #Check for a WO(AFU) that did not result in a landing allegedly, and make sure there was no take off, in which case, make it a bolter.
    if ($lockGrade -eq 0) {
        if ($Grade -match $WOAFU) {
            Write-Output "$(Get-Timestamp) $logInfo $logRegex Found a WO(AFU). Sleeping for 6 seconds to detect a bolter" | Out-file $debugLog -append
            Start-Sleep -Seconds $lsoBolterSleepTimer.TotalSeconds
            $getLandingContext = Select-String -Path $dcsLogPath -Pattern $lsoEventRegex -Context 12 | Select-Object -Last 1 | Out-String
            $getLandingContext = $getLandingContext -Split "`r`n"
            if ($getLandingContext -match $takeoffEventRegex) {
                Write-Output "$(Get-Timestamp) $logInfo $logRegex Found a takeoff event within bolter timeframe." | Out-file $debugLog -append
                $getTakeoffEventPilot = Select-String -Path $dcsLogPath -Pattern $takeoffEventRegex | Select-Object -Last 1
                $getTakeoffEventPilot = $getTakeoffEventPilot -replace "^.*(?:takeoff,initiatorPilotName=)", ""
                $getTakeoffEventPilot = $getTakeoffEventPilot -replace ",.*$", ""
                $getTakeoffEventTime = Select-String -Path $dcsLogPath -Pattern $takeoffEventTimeRegex | Select-Object Matches -Last 1
                    if ($getTakeoffEventTime.Matches.Value -le $trapTime+7) {
                            Write-Output "$(Get-Timestamp) $logInfo $logRegex Detected bolter, grading pass as Bolter" | Out-file $debugLog -append
                            $Grade = $Grade -replace $rGRADE, $BOLTER
                            $Grade = $Grade -replace '\s+', ' '
                            $lockGrade = 1  
                        }
                    else {
                        Write-Output "$(Get-Timestamp) $logInfo $logRegex Did not detect bolter, grading pass as WO" | Out-file $debugLog -append
                        $Grade = $Grade -replace $rGRADE, $WO
                        $Grade = $Grade -replace '\s+', ' '
                        $lockGrade = 1
                    }
                    
                }
                else {
                    Write-Output "$(Get-Timestamp) $logInfo $logRegex Did not detect bolter, grading pass as WO" | Out-file $debugLog -append
                    $Grade = $Grade -replace $rGRADE, $OWO
                    $Grade = $Grade -replace '\s+', ' '
                    $lsoNoBolter = 1
                    $lockGrade = 1
                }
            }
        }


    # Check for automatic Cuts
    if ($lockGrade -eq 0) {
        if (($Grade -match $LLIW) -or 
            ($Grade -match $LRIW) -or
            ($Grades -match $LULIW) -or
            ($Grades -match $LURIW) -or 
            ($Grade -match $SLOIC) -or 
            ($Grade -match $SLOAR) -or 
            ($Grade -match $SLOIW) -or
            ($Grade -match $PPPIC)) {
                Write-Output "$(Get-Timestamp) $logInfo $logRegex Found grossly unsafe deviation. Grading pass as Cut." | Out-file $debugLog -append
                $Grade = $Grade -replace $rGRADE, $CUT
                $Grade = $Grade -replace '\s+', ' '
                $lockGrade = 1
        }
    }

    # Check for TMRDIC or TMRDAR and EGTL or 3PTS for a cut pass OR if TMRDIC or TMRDAR were major deviations

    if ($lockGrade -eq 0) {
        if ((($Grade -match $TMRDIC) -or ($Grade -match $TMRDAR)) -and (($Grade -match $EGTL) -or ($Grade -match $3PTSIW)) ) {
            $Grade = $Grade -replace $rGRADE, $CUT
            $Grade = $Grade -replace '\s+', ' '
            $lockGrade = 1
        }
        elseif ($Grade -match "_TMRD(IC|AR)_") {
            $Grade = $Grade -replace $rGRADE, $CUT
            $Grade = $Grade -replace '\s+', ' '
            $lockGrade = 1
        }
        
    }

    # Check for No Grades
    if ($lockGrade -eq 0) {
        if (($Grade -match $TMRDAR) -or
            ($Grade -match $TMRDIC) -or
            ($Grade -match $3PTSIW) -or  
            ($Grade -match $EGTL) -or 
            ($Grade -match $TMRDIM) -or 
            ($Grade -match $SLOIM) -or 
            ($Grade -match $PPPIC) -or 
            ($Grade -match $PIC) -or
            ($Grade -match $PAR) -or
            ($Grade -match $DRIC) -or 
            ($Grade -match $DLIC) -or 
            ($Grade -match $LULIC) -or 
            ($Grade -match $LURIC) -or 
            ($Grade -match $NERDIC) -or 
            ($Grade -match $DRAR) -or 
            ($Grade -match $DLAR) -or 
            ($Grade -match $NERDAR) -or 
            ($Grade -match $LURAR) -or 
            ($Grade -match $LULAR) -or 
            ($Grade -match $LOAR) -or
            ($Grade -match $LOIW) -or
            ($Grade -match $WAR) -or 
            ($Grade -match $1WIRE) -or
            ($Grade -match $FIW)) {

                Write-Output "$(Get-Timestamp) $logInfo $logRegex Found unsafe deviation. Grading pass as No Grade." | Out-file $debugLog -append
                $Grade = $Grade -replace $rGRADE, $NOGRADE
                $Grade = $Grade -replace '\s+', ' '
                $lockGrade = 1
        }
    }

    #Check for oscillating flight paths and No Grade
    if ($lockGrade -eq 0) {
        if (($Grade -match $LEFT) -and ($Grade -match $RIGHT)) {
            Write-Output "$(Get-Timestamp) $logInfo $logRegex Found oscillating flight path. Grading pass as NO Grade." | Out-file $debugLog -append
            $Grade = $Grade -replace $rGRADE, $NOGRADE
            $Grade = $Grade -replace '\s+', ' '
            $lockGrade = 1        
        }
    }


    # Check for fair passes
    if ($lockGrade -eq 0) {
        if (($Grade -match $DRX) -or 
        ($Grade -match $DLX) -or 
        ($Grade -match $DRIM) -or 
        ($Grade -match $DLIM) -or 
        ($Grade -match $LURIM) -or 
        ($Grade -match $LULIM) -or 
        ($Grade -match $NERDIM) -or 
        ($Grade -match $FIM) -or 
        ($Grade -match $WIM) -or 
        ($Grade -match $FIC) -or 
        ($Grade -match $HIC) -or 
        ($Grade -match $LOIC) -or 
        ($Grade -match $PIC) -or 
        ($Grade -match $WIC) -or 
        ($Grade -match $HAR) -or 
        ($Grade -match $FAR)) {
            Write-Output "$(Get-Timestamp) $logInfo $logRegex Found deviations that were corrected before landing. Graded as Fair." | Out-file $debugLog -append
            $Grade = $Grade -replace $rGRADE, $FAIR
            $Grade = $Grade -replace '\s+', ' '
            $lockGrade = 1
        }
    }

    # Check for OK passes
    if ($lockGrade -eq 0) {
        if (($Grade -match $LULX) -or 
            ($Grade -match $LURX) -or 
            ($Grade -match $FX) -or 
            ($Grade -match $HX) -or 
            ($Grade -match $LOX) -or
            ($Grade -match $HIM) -or 
            ($Grade -match $LOIM) -or
            ($Grade -match $NX) -or 
            ($Grade -match $WX)) {

                Write-Output "$(Get-Timestamp) $logInfo $logRegex Found minor deviations that were corrected before landing. Graded as OK." | Out-file $debugLog -append
                $Grade = $Grade -replace $rGRADE, $OK
                $Grade = $Grade -replace '\s+', ' '
                $lockGrade = 1
        }
    }

    # Check for empty #3 wires and change to _OK_
    if ($Grade -match "GRADE:\S{1,4}\s*?:\s*WIRE#\s*3") {
        Write-Output "$(Get-Timestamp) $logInfo $logRegex Found no deviations and a 3# WIRE. Graded pass as Excellent." | Out-file $debugLog -append
        $Grade = $Grade -replace $rGRADE, $PERFECT
    }
    # Check for empty #2 and #4 wires and switch to OK
    if ($Grade -match "GRADE:\S{1,4}\s*?:\s*WIRE#\s*(2|4)") {
        Write-Output "$(Get-Timestamp) $logInfo $logRegex Found no deviations and a #2 or #4 WIRE. Graded as OK." | Out-file $debugLog -append
        $Grade = $Grade -replace $rGRADE, $OK
    }

    # Trim :
    if ($Grade -match ":\s?(\(|\)|__|_|\s*)\s?:") {
        $Grade = $Grade -replace ":\s?(\(|\)|__|_|\s*)\s?:", ":"
    }

    Write-Output "$(Get-Timestamp) $logInfo $logRegex Regraded Grade: $Grade" | Out-file $debugLog -append

    <# 
    ---------------------------------------------------------------------
                            END REGRADING
    ---------------------------------------------------------------------
    #>


    $Grade = $Grade -replace '\s+', ' '

    #Underline stle as defined by $lsoConfig.underlineStyle
    if ($lsoConfig.underlineStyle -eq "Underline") {
        $Grade = $Grade -replace "_", "__"      
        }
    elseif ($lsoConfig.underlineStyle -eq "APARTS") {
        $Grade = $Grade -replace "_", "\_"
        }
    else {
        $Grade = $Grade -replace "_", "\_"
        }


    #If the difference between the system time and log event time is greater than the time target, stop. 

    if ($diff -gt $scanInterval) {

        Write-Output "$(Get-Timestamp) $logWarning Trap detected at $logTime is too old. Excepted interval was $scanInterval. Discarding." | Out-file $debugLog -append
            # Do Nothing

        }

        #If the $Pilot or $Grade somehow turned up $null or blank, stop
        elseif (($Pilot -eq "System.Object[]") -or ($Grade -eq "System.Object[]")) {

            Write-Output "$(Get-Timestamp) $logError Trap detected at $logTime is malformed. Something went wrong with the regex steps." | Out-file $debugLog -append

        }

        #If the $Pilot or $Grade has a date in the format of ####-##-##, stop. This will happen when AI land as the regex doesn't work correctly without a pilot field in the log event.
        elseif (($Pilot -match "^.*\d{4}\-\d{2}\-\d{2}.*$") -or ($Grade -match "^.*\d{4}\-\d{2}\-\d{2}.*$")) {

            Write-Output "$(Get-Timestamp) $logWarning Trap detected at $logTime contained a date in the pilot name. This indicates that Regex failed because the initiatorPilot field was missing in the landing event, likely AI landing." | Out-file $debugLog -append
        }
        #Create the webhook and send it
        else {
            Write-Output "$(Get-Timestamp) $RawGrade" | Out-file $rawGradelog -append
                   
            #EMBED WEBHOOK 

            if ($lsoConfig.hookStyle -eq "embed") {
                #Create array to store the embed object we're about to create to pass it in to the webhook's payload
                [System.Collections.ArrayList]$lsoHookEmbedArray = @()
                
                #Split the comments from the grade
                $lsoComments = $Grade.Split(":")[-1]
                $Grade = $Grade.Split(":")[0]

                #Pretty colors
                if ($Grade -Match "_OK_") {
                    $embedColor = "835704"
                }
                elseif ($Grade -Match "(?<!_|\()OK") {
                    $embedColor = "41056"
                }
                elseif ($Grade -Match "\(OK") {
                    $embedColor = "31818"
                }   
                elseif ($Grade -Match "---") {
                    $embedColor = "16751120"
                }
                elseif ($Grade -Match "CUT") {
                    $embedColor = "15404878"
                }
                elseif ($Grade -Match "Bolter") {
                    $embedColor = "16756287"
                }
                elseif ($Grade -Match "WO") {
                    $embedColor = "1535929"
                }
                else {
                    $embedColor = "410486"
                }

                #Create embed object
                $hookEmbedObject = [PSCustomObject]@{

                    #title       = $title
                    color       = $embedColor
                    fields      = @(
                    [PSCustomObject]@{ 
                        name = "Pilot"
                        value = $Pilot
                        inline = $true
                        }
                    [PSCustomObject]@{ 
                        name = "Grade"
                        value = $Grade
                        inline = $true
                        }
                    [PSCustomObject]@{ 
                        name = "Comments"
                        value = $lsoComments
                        inline = $true
                        }
                    )

                }

                #Add embed object to array
                $lsoHookEmbedArray.Add($hookEmbedObject) | Out-Null

                #Create the payload
                $hookPayload = [PSCustomObject]@{

                    embeds = $lsoHookEmbedArray

                    }

                    #Send webhook
                try {
                    Invoke-RestMethod -Uri $lsoConfig.webHookUrl -Body ($hookPayload | ConvertTo-Json -Depth 5) -Method Post -ContentType 'application/json'                    
                    Write-Output "$(Get-Timestamp) $logInfo $logDiscord A landing event was detected and sent successfully via Discord." | Out-file $debugLog -append
                    }
                    #If the error was specifically a network exception or IO exception, write friendly log message
                catch [System.Net.WebException],[System.IO.IOException] {
                    Write-Output "$(Get-Timestamp) $logError $logDiscord Failed to establish connection to Discord webhook. Please check that the webhook URL is correct, and activated in Discord." | Out-file $debugLog -append              
                    }
                catch {
                    Write-Output "$(Get-Timestamp) $logError $logDiscord An unknown error occurred attempting to invoke the API request to Discord." | Out-file $debugLog -append
                    }
                
            }

            # BASIC WEBHOOK

            else {
                Write-Output "$(Get-Timestamp) $RawGrade" | Out-file $rawGradelog -append

                            #Message content
                $messageConcent = -join("**Pilot: **", $Pilot, " **Grade:** ", $Grade  )


                #json payload
                $hookPayload = [PSCustomObject]@{
                content = $messageConcent
                    }
                    #The webhook
                try {
                Invoke-RestMethod -Uri $lsoConfig.webHookUrl -Method Post -Body ($hookPayload | ConvertTo-Json) -ContentType 'application/json'  
                Write-Output "$(Get-Timestamp) $logInfo $logDiscord A landing event was detected and sent successfully via Discord." | Out-file $debugLog -append
                 }
                    #If the error was specifically a network exception or IO exception, write friendly log message
                catch [System.Net.WebException],[System.IO.IOException] {
                Write-Output "$(Get-Timestamp) $logError $logDiscord Failed to establish connection to Discord webhook. Please check that the webhook URL is correct, and activated in Discord." | Out-file $debugLog -append            
                }
                catch {
                Write-Output "$(Get-Timestamp) $logError $logDiscord An unknown error occurred attempting to invoke the API request to Discord." | Out-file $debugLog -append
                }
            }

        }
    }

    #Get the run duration of the loop, and convert to the amount of milliseconds the loop should sleep for which is the scan interval minus the run duration
    $lsoLoopEndSysTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $lsoLoopDuration = $lsoLoopDuration = New-TimeSpan -Start $lsoLoopStartSysTime -End $lsoLoopEndSysTime
    Write-Output "$(Get-Timestamp) $logInfo LSO BOT loop duration was $lsoLoopDuration" | Out-file $debugLog -append

    $lsoSleepTime = ($scanInterval.TotalMilliseconds - $lsoLoopDuration.TotalMilliseconds) 
    Write-Output "$(Get-Timestamp) $logInfo Sleep duration is now $lsoSleepTime based on $scanInterval - $lsoLoopDuration" | Out-file $debugLog -append

    Write-Output "$(Get-Timestamp) $logInfo LSO BOT Cycle Ran. Sleeping for $lsoSleepTime milliseconds" | Out-file $debugLog -append

    Start-Sleep -Milliseconds $lsoSleepTime
}

#Garbage Collection
[system.gc]::Collect()