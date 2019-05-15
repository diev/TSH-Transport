<#
.SYNOPSIS 
Работа с сервером ТШ КБР.

.DESCRIPTION
Прием и отправка платежных XML по HTTP протоколу в систему ТШ КБР.  

.PARAMETER Verbose
Режим подробных сообщений.

.PARAMETER Debug
Режим отладки.

.INPUTS
Конфигурация берется из Config.ps1 в папке программы.

.OUTPUTS
Логи ведутся в папку Logs, файлы раскидываются согласно конфига.

.EXAMPLE
PS> .\TshTrans -Test

.EXAMPLE
CMD> %windir%\System32\WindowsPowerShell\v1.0\powershell.exe -nologo -noprofile %~dpn0.ps1 -Debug

.NOTES
TODO:
https://docs.microsoft.com/ru-ru/powershell/module/microsoft.powershell.core/about/about_comment_based_help?view=powershell-5.1

.LINK
https://github.com/diev/TSH-Transport
#>

param
(
    [switch] $Verbose,
    [switch] $Debug,
    [switch] $Test
)

if ($Verbose) { $VerbosePreference = 'Continue' } # default is 'SilentlyContinue'
if ($Debug)   { $DebugPreference   = 'Continue' } # default is 'SilentlyContinue'

$Version = '3.0.0' # 2019-05-13
$AppName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)
$AppPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

$AppLogs   = Join-Path -Path $AppPath -ChildPath Logs
$AppConfig = Join-Path -Path $AppPath -ChildPath Get-Config.ps1

$AppLog = Join-Path -Path $AppLogs -ChildPath '%Y%m%d.log' # 20190507

function Main
{
    New-Dir $AppLogs | Out-Null

    if ($Verbose) { "Режим подробных сообщений (-Verbose)" | Write-Log }

    if ($Debug) { "Режим отладки (-Debug)" | Write-Log
        try { Stop-Transcript -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null } catch {}

        $file = Get-Date -UFormat '%Y%m%d-%H%M%S-debug.log' # 20190507-191015
        $file = Join-Path -Path $AppLogs -ChildPath $file
        try { Start-Transcript -Path $file -Append -Force | Out-Null } catch {}
    }

    "Старт $AppName $Version" | Write-Log

    if (!(Test-Path -Path $AppConfig -PathType Leaf))
    {
        "Конфиг $AppConfig не найден" | Write-Log
        return
    }

    . $AppConfig

    if ($null -eq $ConfigCredential)
    {
        "Логин и пароль к серверу не заданы" | Write-Verbose
        return
    }

    $out = New-Dir $ConfigPathOut
    #if ((Get-Item $out).FullName.StartsWith($AppPath))
    if ((Get-Item $out).FullName -eq $AppPath)
    {
        "Запрещено отправлять из $AppPath" | Write-Log -Level Warning
        return
    }

    do
    {
        "Проверка директории отправки $out" | Write-Verbose
        $files = (Get-ChildItem -Path $out -File).FullName
        if ($files.Length -gt 0)
        {
            $files | Send-HttpData
        }

        "Проверка списка на сервере" | Write-Verbose
        Get-HttpList

        if ($Test) {
            "Режим одноразового запуска (-Test)" | Write-Verbose
            break
        }
    }
    while (Start-Countdown)

    "Выход`r`n" | Write-Log
    if ($Debug) { Stop-Transcript | Out-Null }
}

function Start-Countdown
{
    while ($Host.UI.RawUI.KeyAvailable)
    {
        [void] $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown,IncludeKeyUp')
    }

    $watcher = New-Object System.IO.FileSystemWatcher (New-Dir $ConfigPathOut)

    $hour = (Get-Date).Hour
    if ($hour -ge 23 -or $hour -lt 7) {
        $mins = 30 # 23:00..7:30
    } else {
        $mins = 5
    }
    $timeX = (Get-Date).AddMinutes($mins)

    while ($true)
    {
        $timeSpan = New-TimeSpan -Start (Get-Date) -End $timeX
        [System.Console]::Write($timeSpan.ToString('mm\:ss'))
        [System.Console]::CursorLeft = 0

        if ($timeSpan.TotalSeconds -le 0) { break }

        $result = $watcher.WaitForChanged('Created', 1000) # 1 sec timeout
        if ($result.TimedOut -eq $false) { break } # " Файл! " + $result.Name

        if ($Host.UI.RawUI.KeyAvailable)
        {
            $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown,IncludeKeyUp')

            if ($key.VirtualKeyCode -eq 32) { break } # Space

            if ($key.VirtualKeyCode -eq 27) { return $false } # Esc
        }
    }
    $true
}

function Get-HttpList
{
    param
    (
        [string] $Path = ''
    )

    if ($Path -eq '')
    {
        $format = '%Y%m%d-%H%M%S-list.xml' # 20190507-191015
        $Path = Join-Path -Path $AppLogs -ChildPath (Get-Date -UFormat $format)
        while (Test-Path -Path $Path -PathType Leaf)
        {
            Start-Sleep -Seconds 1
            $Path = Join-Path -Path $AppLogs -ChildPath (Get-Date -UFormat $format)
        }
    }

    $fileName = Split-Path -Path $Path -Leaf
    $url = "/get?Method=List&Count=50"

    $url | Write-Log -Level Verbose

    if ($null -eq $ConfigCredential)
    {
        "Логин и пароль к серверу не заданы" | Write-Verbose
        return
    }

    $request = [System.Net.WebRequest]::Create($ConfigUrl + $url)
    $request.Accept = 'application/soap+xml'
    $request.Credentials = $ConfigCredential
    $request.KeepAlive = $false
    $request.Method = 'GET'
    $request.Pipelined = $true
    $request.ProtocolVersion = [System.Net.HttpVersion]::Version11
    $request.Proxy = $null
    $request.Timeout = 30000 # ms
    $request.UserAgent = "$AppName $Version"

    try
    {
        $response = $request.GetResponse()
        if ($null -ne $response)
        {
            $scode = $response.StatusCode
            [int] $code = $scode
            "Ответ $code ($scode)" | Write-Log -Level Verbose

            if ($code -eq 204) # [System.Net.HttpStatusCode]::NoContent
            {
                "Список пуст на сервере" | Write-Verbose
            }
            elseif ($code -eq 200) # [System.Net.HttpStatusCode]::OK
            {
                $responseStream = $response.GetResponseStream()
                $fileStream = New-Object -TypeName System.IO.FileStream -ArgumentList $Path, Create
                $bytes = Write-Stream -Source $responseStream -Destination $fileStream -FileName $fileName
                
                if ($bytes -gt 0)
                {
                    "  > $fileName $bytes" | Write-Log
                }
                else { "Файл $fileName нулевого размера!" | Write-Log -Level Warning }
            }
            else { "Сервер вернул код $code ($($response.StatusCode))" | Write-Log }
        }
        else { "Нет ответа сервера" | Write-Log -Level Warning }
    }
    finally
    {
        if ($null -ne $fileStream)     { $fileStream.Close(); $fileStream.Dispose() }
        if ($null -ne $responseStream) { $responseStream.Close(); $responseStream.Dispose() }
        if ($null -ne $response)       { $response.Close() }
        $request = $null
    }

    if (Test-Path -Path $Path -PathType Leaf)
    {
        [XML] $xml = Get-Content -Path $Path
        $table = $xml.MessageList.MessageItem
        if ($Verbose)
        {
            $table | Format-Table -AutoSize
        }
        # $table | Get-HttpData
        foreach ($row in $table) {
            $id = $row.InstanceID
            $fileName = $row.LegacyTransportFileName

            if ($fileName -eq '')
            {
                $fileName = "$id.xml" # TODO: shorten name?
                $backup = New-Dir (Get-Dated "$ConfigBackupRep")
                $backFile = Join-Path -Path $backup -ChildPath $fileName
                Get-HttpData -Id $id -FileName $fileName -Path $backFile
            }
            else
            {
                $backup = New-Dir (Get-Dated "$ConfigBackupIn")
                $backFile = Join-Path -Path $backup -ChildPath $fileName
                $in = New-Dir $ConfigPathIn
                Get-HttpData -Id $id -FileName $fileName -Path $backFile -Destination $in
            }
        }
    }   
}

function Get-HttpData
{
    param
    (
        [string] $Id,
        [string] $FileName,
        [string] $Path,
        [string] $Destination = ''
    )

    $url = "/get?Method=Download&InstanceID=$Id"
    $bytes = 0

    "$url > $FileName" | Write-Log -Level Verbose

    if ($null -eq $ConfigCredential)
    {
        "Логин и пароль к серверу не заданы" | Write-Verbose
        return
    }

    $request = [System.Net.WebRequest]::Create($ConfigUrl + $url)
    $request.Accept = 'application/soap+xml'
    $request.Credentials = $ConfigCredential
    $request.KeepAlive = $false
    $request.Method = 'GET'
    $request.Pipelined = $true
    $request.ProtocolVersion = [System.Net.HttpVersion]::Version11
    $request.Proxy = $null
    $request.Timeout = 30000 # ms
    $request.UserAgent = "$AppName $Version"

    try
    {
        $response = $request.GetResponse()
        if ($null -ne $response)
        {
            [int] $code = $response.StatusCode
            if ($code -eq 200) # [System.Net.HttpStatusCode]::OK
            {
                $responseStream = $response.GetResponseStream()
                $fileStream = New-Object -TypeName System.IO.FileStream -ArgumentList $Path, Create
                $bytes = Write-Stream -Source $responseStream -Destination $fileStream -FileName $FileName
            }
            else { "Сервер вернул код $code ($($response.StatusCode)) вместо $FileName" | Write-Log }
        }
        else { "Нет ответа сервера" | Write-Log -Level Warning }
    }
    finally
    {
        if ($null -ne $fileStream)     { $fileStream.Close(); $fileStream.Dispose() }
        if ($null -ne $responseStream) { $responseStream.Close(); $responseStream.Dispose() }
        if ($null -ne $response)       { $response.Close() }
        $request = $null
    }
        
    if ($bytes -gt 0 -and (Test-Path -Path $Path -PathType Leaf))
    {
        try
        {
            [xml] $xml = Get-Content $Path

            "    > $FileName $bytes" | Write-Log

            if ($Destination -ne '')
            {
                New-Dir $Destination | Out-Null
                Copy-Item -Path $Path -Destination $Destination -Force
            }
            Remove-HttpData -Id $Id
        }
        catch
        {
            "Файл $FileName не XML!" | Write-Log -Level Warning
        }
    }
    else { "Файл $FileName нулевого размера!" | Write-Log -Level Warning }
}

function Remove-HttpData
{
    param
    (
        [string] $Id
    )

    $url = "/get?Method=Delete&InstanceID=$Id"

    $url | Write-Log -Level Verbose

    if ($null -eq $ConfigCredential)
    {
        "Логин и пароль к серверу не заданы" | Write-Verbose
        return
    }

    $request = [System.Net.WebRequest]::Create($ConfigUrl + $url)
    $request.Accept = ''
    $request.Credentials = $ConfigCredential
    $request.KeepAlive = $false
    $request.Method = 'GET'
    $request.Pipelined = $true
    $request.ProtocolVersion = [System.Net.HttpVersion]::Version11
    $request.Proxy = $null
    $request.Timeout = 30000 # ms
    $request.UserAgent = "$AppName $Version"

    try
    {
        $response = $request.GetResponse()
        if ($null -ne $response)
        {
            [int] $code = $response.StatusCode
            if ($code -eq 200) # [System.Net.HttpStatusCode]::OK
            {
                "$id удален с сервера" | Write-Log -Level Verbose
            }
            else { "Сервер вернул код $code ($($response.StatusCode)) на удаление" | Write-Log }
        }
    }
    finally
    {
        if ($null -ne $response) { $response.Close() }
        $request = $null
    }
}

function Send-HttpData {
    param (
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
        [string] $Path
    )

    begin {
        $backup = New-Dir (Get-Dated "$ConfigBackupOut")
        $url = '/in'
    }

    process {
        $fileName = Split-Path -Path $Path -Leaf
        $backFile = Join-Path -Path $backup -ChildPath $fileName
        Start-Sleep -Seconds 2 # delay to close network streaming (TODO: wait closing)
        Copy-Item -Path $Path -Destination $backup -Force
        if (!(Test-Path -Path $backFile -PathType Leaf)) {
            "Ошибка сохранения в $backFile" | Write-Log -Level Warning
            return
        }

        "$url < $Path" | Write-Log -Level Verbose

    if ($null -eq $ConfigCredential)
    {
        "Логин и пароль к серверу не заданы" | Write-Verbose
        return
    }

        $request = [System.Net.WebRequest]::Create($ConfigUrl + $url)
        $request.ContentType = 'application/xmlepd'
        $request.Credentials = $ConfigCredential
        $request.KeepAlive = $true
        $request.Method = 'POST'
        $request.Pipelined = $true
        $request.ProtocolVersion = [System.Net.HttpVersion]::Version11
        $request.Proxy = $null
        $request.Timeout = 30000 # ms
        $request.UserAgent = "$AppName $Version"

        try
        {
            $requestStream = $request.GetRequestStream()
            if ($null -ne $requestStream)
            {
                $fileStream = New-Object -TypeName System.IO.FileStream -ArgumentList $Path, Open
                $bytes = Write-Stream -Source $fileStream -Destination $requestStream -FileName $fileName

                $response = $request.GetResponse()
                if ($null -ne $response)
                {
                    [int] $code = $response.StatusCode
                    if ($code -eq 201 -or $code -eq 202) # [System.Net.HttpStatusCode]::Created, [System.Net.HttpStatusCode]::Accepted
                    {
                        "< $fileName $bytes" | Write-Log
                        Remove-Item -Path $Path -Force
                    }
                    else { "Сервер вернул код $code ($($response.StatusCode)) на отправку $fileName" | Write-Log }
                }
                else { "Нет ответа сервера" | Write-Log -Level Warning }
            }
            else { "Нет запроса сервера" | Write-Log -Level Warning }
        }
        finally
        {
            if ($null -ne $fileStream)    { $fileStream.Close(); $fileStream.Dispose() }
            if ($null -ne $requestStream) { $requestStream.Close(); $requestStream.Dispose() }
            if ($null -ne $response)      { $response.Close() }
            $request = $null
        }
    }
}

function Write-Stream
{
    param
    (
        [System.IO.Stream] $Source,
        [System.IO.Stream] $Destination,
        [string] $FileName
    )

    $buffer = New-Object byte[] 4KB
    $bytes = 0

    try
    {
        do
        {
            $count = $Source.Read($buffer, 0, $buffer.Length)
            $Destination.Write($buffer, 0, $count)
            $bytes += $count
#            [System.Console]::CursorLeft = 0
#            [System.Console]::Write("$FileName $bytes")
        }
        while ($count -ne 0)
        $Destination.Flush()
#        [System.Console]::WriteLine(" OK")
    }
    catch {
        [System.Console]::WriteLine(" Error!")
        "Ошибка стрима $FileName ($bytes bytes завершено)" | Write-Log -Level Warning
        $bytes = -$bytes
    }
    finally {
        $Destination.Close()
        $Destination.Dispose()

        $Source.Close()
        $Source.Dispose()
    }
    return $bytes
}

function Get-Dated
{
    param
    (
        [Parameter(ValueFromPipeline = $true, Position = 1)]
        [string] $Format = $AppLog
    )

    Get-Date -UFormat $Format
}

function Write-Log
{
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string] $Message,
        [ValidateSet('Error', 'Warning', 'Verbose', 'Output')]
        [string] $Level = 'Output',
        [string] $Path = (Get-Dated),
        [string] $Format = 'HH:mm:ss'
    )

    $timeStamp = Get-Date -Format $Format
    $Message = "$timeStamp $levelText$Message"
    switch ($Level) {
        'Error'   { Write-Error   $Message; $levelText = 'ERROR: '   }
        'Warning' { Write-Warning $Message; $levelText = 'WARNING: ' }
        'Verbose' { Write-Verbose $Message; $levelText = 'VERBOSE: ' }
        'Output'  { Write-Output  $Message; $levelText = ''          }
    }
    $encoding = [System.Text.Encoding]::GetEncoding(1251)

    if ($Level -eq 'Verbose' -and -not $Verbose) { return }

    try
    {
        if (!(Test-Path -Path $Path -PathType Leaf))
        {
            New-Item -Path $Path -ItemType File -Force | Out-Null
        }
        [System.IO.File]::AppendAllText($Path, "$Message`r`n", $encoding)
    }
    catch { "Невозможно записать в лог $Path : $Message" | Write-Warning }
}

function New-Dir
{
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)]
        [string] $Path,
        [switch] $Dated
    )

    if ($Dated) { $Path = Get-Dated $Path }
    if (!(Test-Path -Path $Path -PathType Container))
    {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
    $Path
}

Main
# eof
