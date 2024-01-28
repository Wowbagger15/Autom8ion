# region synopsis

<#
    .SYNOPSIS
    Shows a dialog with system information significant to end-users seeking/consulting (remote) support

    .DESCRIPTION
    This script shows upon start a dialog holding system information that can be used in a (remote) support
    situation by service engineers and the like.
    It also offers a set of tools that can be easily launched from the same window.
    Values can be copied by clicking on them and the tool is easily closed via enter and escape keys

    .PARAMETER me
    Specifies the caption title shown

    .PARAMETER bye
    Specifies the closing message echoed in the controlling console window

    .PARAMETER width
    Specifies the width of the dialog in Windows native points, defaults to 512.

    .PARAMETER height
    Specifies the minimum height of the dialog in Windows native points, defaults to 256. Height is currently adjusted based on information lines and icons shown.

    .PARAMETER position
    Specifies the initial position of the dialog. Valid values (*not* case sensitive) are "leftTop", "rightTop", "leftBottom", "rightBottom", "center". Defaults to "center".

    .PARAMETER transparency
    Specifies the transparency of the dialog. Defaults to 0.9, i.e. 90% opaque.

    .PARAMETER background
    Specifies the background color. Defaults to "#FFFFFF"

    .PARAMETER test
    Does not perform the rather costly inventory but only shows dialog with tool icons.

    .INPUTS
    None. No pipeline support.

    .OUTPUTS
    None. Only visible GUI elements.

    .EXAMPLE
    PS> <scriptname> -me "Cromwell Inc. ICT services support tool" -bye "Tool closed. If this window remains open, it is safe to close." -position "rightBottom";

    .NOTES
    Author: R.J. de Vries (Autom8ion@3Bdesign.nl)
    GitHub: WowBagger15/Autom8ion
    Release notes:
        Version 1.2     : Introduced minimalist mode, added logging, renamed main canvas function
        Version 1.0.1   : Fixed position calculation bug, erroneously using double pipe instead of -bor
        Version 1.0     : First version cleaned up of comments and debug lines
        Version 0.9     : Init
#>

# endregion synopsis

# region interface

[cmdLetBinding( defaultParameterSetName = "normal" )]
param(
    [string]
    $me  = "BIS - System information"
    ,
    [parameter( parameterSetName = "normal" )]
    [string]
    $bye = "Ready. This window may be closed."
    ,
<#
    #!  PowerShell desktop edition does not like unknown classes in a script's interface
    [System.Drawing.Size]
    $size                          = [System.Drawing.Size]::new( 512, 256 )
    ,
#>
    [parameter( parameterSetName = "normal" )]
    [int]
    $width                         = 512
    ,
    [parameter( parameterSetName = "normal" )]
    [int]
    $height                        = 256
    ,
    [parameter( parameterSetName = "normal" )]
    [validateSet(
            "leftTop"
        ,   "rightTop"
        ,   "leftBottom"
        ,   "rightBottom"
        ,   "center"
    )]
    [string]
    $position                      = "center"
    ,
    [double]
    $transparency                  = 0.9
    ,
    [string]                       # [System.Drawing.Color]
    $background                    = "#FFFFFF"
    ,
    [string]
    $log                           = ( join-path -path ( [system.io.path]::getTempPath() ) -childPath ( ( $me, "log" ) -join '.' ) )
    ,
    [parameter( parameterSetName = "minimalist" )]
    [switch]
    $minimalist
    ,
    [switch]
    $test
)
# endregion interface

# region begin references

add-type -assemblyName "System.Drawing";
add-type -assemblyName "System.Windows.Forms";
# add-type -assemblyName "PresentationCore","PresentationFramework";
# https://dexterposh.blogspot.com/2014/09/powershell-wpf-gui-hide-use-background.html
# Credits to - http://powershell.cz/2013/04/04/hide-and-show-console-window-from-gui/
add-type -name "Window" -namespace "Console" -memberDefinition @'
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'@;

# https://www.powershellgallery.com/packages/IconForGUI/1.5.2/Content/IconForGUI.psm1
add-type -name "Icon" -namespace "Win32API" -memberDefinition @'
[DllImport("Shell32.dll", SetLastError=true)]
public static extern int ExtractIconEx(string lpszFile, int nIconIndex, out IntPtr phiconLarge, out IntPtr phiconSmall, int nIcons);

[DllImport("gdi32.dll", SetLastError=true)]
public static extern bool DeleteObject(IntPtr hObject);
'@;

# endregion references

# region begin variables

$__ = @{
    version   = '1.0.1'
    dialog = @{
        margin                     = 32
        position = @{
            "leftTop"              = $null
            "rightTop"             = $null
            "leftBottom"           = $null
            "rightBottom"          = $null
            "center"               = [System.Windows.Forms.FormStartPosition]::centerScreen
        }
    }
    gauge = @{
        bar = @{
            style = @{
                "EqualThin"    = @( [char]9632, [char]9632, [char]9632, [char]0045 )
                "EqualThick1"  = @( [char]9608, [char]9608, [char]9608, [char]0045 )
                "EqualThick2"  = @( [char]9612, [char]9612, [char]9612, [char]0045 )
                "GrowingThin1" = @( [char]9632, [char]9632, [char]9632, [char]9476 )
                "GrowingThin2" = @( [char]9642, [char]9642, [char]9642, [char]9643 )
                "GrowingThick" = @( [char]9617, [char]9618, [char]9619, [char]9482 )
            }
        }
    }
    system = @{
        chassis = @{
            "Other"                 = 01
            "Unknown"               = 02
            "Desktop"               = 03
            "Low Profile Desktop"   = 04
            "Pizza Box"             = 05
            "Mini Tower"            = 06
            "Tower"                 = 07
            "Portable"              = 08
            "Laptop"                = 09
            "Notebook"              = 10
            "Hand Held"             = 11
            "Docking Station"       = 12
            "All in One"            = 13
            "Sub Notebook"          = 14
            "Space-Saving"          = 15
            "Lunch Box"             = 16
            "Main System Chassis"   = 17
            "Expansion Chassis"     = 18
            "SubChassis"            = 19
            "Bus Expansion Chassis" = 20
            "Peripheral Chassis"    = 21
            "Storage Chassis"       = 22
            "Rack Mount Chassis"    = 23
            "Sealed-Case PC"        = 24
            "Tablet"                = 30
            "Convertible"           = 31
            "Detachable"            = 32
        }
    }
    scale = @"
    [
        { "index": 0    , "name": "yotta"   , "symbol": "Y"     , "base":  24   , "short": "septillion"         , "long": "quadrillion"     , "iso": 0  , "isq": 0 },
        { "index": 1    , "name": "zetta"   , "symbol": "Z"     , "base":  21   , "short": "sextillion"         , "long": "trilliard"       , "iso": 0  , "isq": 0 },
        { "index": 2    , "name": "exa"     , "symbol": "E"     , "base":  18   , "short": "quintillion"        , "long": "trillion"        , "iso": 0  , "isq": 0 },
        { "index": 3    , "name": "peta"    , "symbol": "P"     , "base":  15   , "short": "quadrillion"        , "long": "billiard"        , "iso": 0  , "isq": 0 },
        { "index": 4    , "name": "tera"    , "symbol": "T"     , "base":  12   , "short": "trillion"           , "long": "billion"         , "iso": 0  , "isq": 0 },
        { "index": 5    , "name": "giga"    , "symbol": "G"     , "base":  9    , "short": "billion"            , "long": "milliard"        , "iso": 0  , "isq": 0 },
        { "index": 6    , "name": "mega"    , "symbol": "M"     , "base":  6    , "short": "million"            , "long": "million"         , "iso": 0  , "isq": 0 },
        { "index": 7    , "name": "kilo"    , "symbol": "k"     , "base":  3    , "short": "thousand"           , "long": "thousand"        , "iso": 0  , "isq": 0 },
        { "index": 8    , "name": "hecto"   , "symbol": "h"     , "base":  2    , "short": "hundred"            , "long": "hundred"         , "iso": 0  , "isq": 0 },
        { "index": 9    , "name": "deca"    , "symbol": "da"    , "base":  1    , "short": "ten"                , "long": "ten"             , "iso": 0  , "isq": 0 },
        { "index": 10   , "name": ""        , "symbol": ""      , "base":  0    , "short": "one"                , "long": "one"             , "iso": 0  , "isq": 0 },
        { "index": 11   , "name": "deci"    , "symbol": "d"     , "base": -1    , "short": "tenth"              , "long": "tenth"           , "iso": 0  , "isq": 0 },
        { "index": 12   , "name": "centi"   , "symbol": "c"     , "base": -2    , "short": "hundredth"          , "long": "hundredth"       , "iso": 0  , "isq": 0 },
        { "index": 13   , "name": "milli"   , "symbol": "m"     , "base": -3    , "short": "thousandth"         , "long": "thousandth"      , "iso": 0  , "isq": 0 },
        { "index": 14   , "name": "micro"   , "symbol": "μ"     , "base": -6    , "short": "millionth"          , "long": "millionth"       , "iso": 0  , "isq": 0 },
        { "index": 14   , "name": "micro"   , "symbol": "mu"    , "base": -6    , "short": "millionth"          , "long": "millionth"       , "iso": 0  , "isq": 0 },
        { "index": 15   , "name": "nano"    , "symbol": "n"     , "base": -9    , "short": "billionth"          , "long": "milliardth"      , "iso": 0  , "isq": 0 },
        { "index": 16   , "name": "pico"    , "symbol": "p"     , "base": -12   , "short": "trillionth"         , "long": "billionth"       , "iso": 0  , "isq": 0 },
        { "index": 17   , "name": "femto"   , "symbol": "f"     , "base": -15   , "short": "quadrillionth"      , "long": "billiardth"      , "iso": 0  , "isq": 0 },
        { "index": 18   , "name": "atto"    , "symbol": "a"     , "base": -18   , "short": "quintillionth"      , "long": "trillionth"      , "iso": 0  , "isq": 0 },
        { "index": 19   , "name": "zepto"   , "symbol": "z"     , "base": -21   , "short": "sextillionth"       , "long": "trilliardth"     , "iso": 0  , "isq": 0 },
        { "index": 20   , "name": "yocto"   , "symbol": "y"     , "base": -24   , "short": "septillionth"       , "long": "quadrillionth"   , "iso": 0  , "isq": 0 }
    ]
"@ | convertFrom-Json
};

$__.scale |% {
    # compute iso and isq scale starting values when loading this module
    $_.iso = [math]::pow( 10, $_.base );
    # isq scales only apply to numbers higher than 1 and every third base
    if ( $_.base -ge 0 -and $_.base % 3 -eq 0 ) {
        $_.isq = [math]::pow( 1024, [math]::floor( $_.base / 3 ) );
    }
}

$__.dialog.position.leftTop         = [System.Drawing.Point]::new( $__.dialog.margin                                                                           , $__.dialog.margin                                                                             );
$__.dialog.position.rightTop        = [System.Drawing.Point]::new( [System.Windows.Forms.Screen]::primaryScreen.WorkingArea.Width - $__.dialog.margin - $width , $__.dialog.margin                                                                             );
$__.dialog.position.leftBottom      = [System.Drawing.Point]::new( $__.dialog.margin                                                                           , [System.Windows.Forms.Screen]::primaryScreen.WorkingArea.Height - $__.dialog.margin - $height );
$__.dialog.position.rightBottom     = [System.Drawing.Point]::new( [System.Windows.Forms.Screen]::primaryScreen.WorkingArea.Width - $__.dialog.margin - $width , [System.Windows.Forms.Screen]::primaryScreen.WorkingArea.Height - $__.dialog.margin - $height );

# endregion variables

# region routines
function invoke-ternary {
<#
.SYNOPSIS
    Provides a ternary operator as, for example, implemented in C# and JavaScript using the colon. The cmdlet is aliased as '?:'.
.PARAMETER test
    A scriptblock which result is converted to either true or false
.PARAMETER is
    Scriptblock to execute when the test block yields true
.PARAMETER not
    Scriptblock to execute when the test block yields false
.EXAMPLE $color = ?: { $eyes > 3 } { 'blue' } { 'red' }
#>
    [cmdletBinding()] 
    param (
        [parameter( mandatory = $true, position = 0 )]
        [scriptblock]$test
        ,
        [parameter( position = 1 )]
        [scriptblock]$is = { }
        ,
        [parameter( position = 2 )]
        [scriptblock]$not = { }
    )
    process {
        if ( & $test ) {
            & $is
        } else {
            & $not
        }
    }
}
function coalesce {
<#
.SYNOPSIS
    Provides a coalesce filter for the assignment of values return the first non-null value in the array;
.PARAMETER Values
    Array of values of which the first non-null value is returned
.PARAMETER Mode
    Comparison mode where 0 means normal false checking, 1 means string compare appraising empty string as false and 2 means only nulls return false (even $false or 0 yield $true)
.PARAMETER Default
    Value to return in case no value yields $true, default is $null
.EXAMPLE $result = ?0 $first, $second, 'default';
#>
    [cmdletBinding()] 
    param (
        [parameter( position = 0 )]
        $_values
        ,
        [parameter( position = 1 )]
        [int]
        $mode = 0
        ,
        [parameter( position = 2 )]
        $default = $null
    )
    process {
        forEach ( $value in $_values ) {
            # TODO::Elegantize and use enum
            # TODO::Reverse order in mode 2, refer to https://stackoverflow.com/a/5111612
            switch ( $mode ) {
                0 { if ( $value                                                                    ) { return $value }; continue;  break; }
                1 { if ( $value -is [string] -and [string]::IsNullOrEmpty( $value ) -eq $false     ) { return $value }; continue;  break; }
                2 { if ( $null -ne $value                                                          ) { return $value }; continue;  break; }
            }
        }
        return $default;
    }
}
function convertTo-humanReadable{
<#
.SYNOPSIS
    Converts numerical input to human readable strings
.PARAMETER source
    Source(s) to be converted
.PARAMETER isq
    Whether to use powers of 1000 (kiB) instead of 1024 (kB)
.PARAMETER unit
    String to be appended to the formatted result and (resulting) scale, e.g. 'B' or 'Hz'
.PARAMETER scale
    What scale to force source to. If not set the scale is determined automatically based on source's size
.PARAMETER precision
    Defaults to 0, i.e. integer output, otherwise number of decumal digits
.PARAMETER pad
    String to be used between (formatted) result and scale (and unit)
.PARAMETER culture
    Culture to be used for grouping and decimal symbols
.PARAMETER bare
    Returns only calculated value
.EXAMPLE
    '# [{0}]' -f ( convertTo-humanReadable -source 45644 -scale 'k' -unit 'Hz' -group -pad ' ' );
    # [46 kHz];
#>
    [cmdletBinding()]
    param (
        [parameter( mandatory = $true, valueFromPipeline = $true )]
        [valueType[]]
        $source
        ,
        [switch]
        $isq
        ,
        [string]
        $unit
        ,
        # [validateLength( 0, 2 )]
        [validateScript( {
            if ( ( $null -eq $_ ) -or ( $_ -in $__.scale.symbol ) ) {
                $true
            } else {
                throw ( 'Scale must be one of [{0}]' -f ( $__.scale.symbol -join '], [' ) )
            }
        } )]
        [string]
        $scale
        ,
        [int]
        $precision = 0
        ,
        [switch]
        $group
        ,
        [string]
        $pad = ''
        ,
        [cultureInfo]
        $culture
        ,
        [switch]
        $bare
    )
    begin {
        $_base = ?: { $isq } { "isq" } { "iso" };
        if ( $bare ) {
            $_format = '{{0:{0}{1}}}{2}{3}' -f ( ?: { $group } { 'N' } { 'f' } ), $precision, $pad, ( ?0 -mode 2 $unit, '' );
        } else {
            $_format = '{{0:{0}{1}}}{2}{{1}}{3}{4}' -f ( ?: { $group } { 'N' } { 'f' } ), $precision, $pad, ( ?: { $isq } { 'i' } ), ( ?0 -mode 2 $unit, '' );
        }
        $_scaled = $PSboundParameters.containsKey( "scale" );
        # 'Using format [{0}]' -f $_format | out-host;
        # https://stackoverflow.com/a/37603732
        if ( $culture ) {
            [cultureinfo]::currentculture = $culture;
        }
    }
    process {
        forEach( $_accu in @( ?0 $input, $source, @() ) ) {
            $__.scale |? {
                $_.( $_base ) -gt 0
            } |? {
                ( -not $_scaled -and $_.( $_base ) -lt $_accu )   `
                -or                                             `
                ( $_scaled -and $_.symbol -ceq $scale )           `
            } | sort-object index | select-object -first 1 |% {
                # 'Using scale [{0}]' -f $_.name | out-host;
                # $_ | ft | out-host;
                # WARNING::Due to operator precedence, any expression as the RHS of -f *must* be
                #          enclosed in () to make culture sensitive formatting work !!!
                # https://stackoverflow.com/a/37603732
                $_format -f ( $_accu / $_.( $_base ) ), $_.symbol;
            }
        }
    }
}
function out-gauge {
    <#
.SYNOPSIS
    Show gauge for value/maximum. Currently supports bar style.
.DESCRIPTION
    This cmdlet creates a gauge showing a value relative to a maximum. Currently supports bar style.
.PARAMETER Percentage
    Value in percents (%).
.PARAMETER Value
    Value in arbitrary units.
.PARAMETER Maximum
    100% value.
.PARAMETER Size
    For bar style, length in characters.
.PARAMETER Style
    Styling of the gauge. Currently, only presets are supported.
.PARAMETER Level2
    Percent value to change color from green to yellow (relevant only when drawing the gauge).
.PARAMETER Level3
    Percent value to change color from yellow to red (relevant only when drawing the gauge).
.PARAMETER Bare
    Exclude percentage number and sign from the gauge.
.PARAMETER Draw
    Directly draws the colored gauge onto the PowerShell console (unsuitable for calculated properties).
.EXAMPLE
    PS C:\> out-gauge -percentage 90 -draw
    Draw single bar with all default settings.
.EXAMPLE
    PS C:\> out-gauge -percentage 95 -draw -level2 70 -level3 90
    Draw the gauge and move both color change borders.
.EXAMPLE
    PS C:\> 85 | out-gauge -draw bare
    Pipeline the percentage value to the function and exclude percentage number and sign from the gauge.
.EXAMPLE
    PS C:\> for ( $i=0; $i -le 100; $i += 10 ) { out-gauge -percentage $i -draw -length 100 -style AdvancedThin2; "`r" }
    Demonstrates advanced gauge style with custom size and different percentage values.
.EXAMPLE
    PS C:\> $Folder = 'C:\reports\';
    PS C:\> $FolderSize = ( Get-ChildItem -Path $Folder | measure -Property Length -Sum ).Sum;
    PS C:\> Get-ChildItem -Path $Folder -File | sort Length -Descending | select -First 10 | select Name,Length,@{ N = 'SizeBar'; E = { out-gauge -value $_.Length -maximum $FolderSize } } |ft -auto;
    Get file size report and add calculated property 'SizeBar' that contains the percentage of each file size from the folder size.
.EXAMPLE
    PS C:\> $VolumeC = gwmi Win32_LogicalDisk |? { $_.DeviceID -eq 'c:' };
    PS C:\> Write-Host -NoNewline "Volume C Usage:" -ForegroundColor Yellow; `
    PS C:\> out-gauge -value ( $VolumeC.Size - $VolumeC.Freespace ) -maximum $VolumeC.Size -draw; "`r"
    Get system volume usage report.
.NOTES
    Author         ::    Roman Gelman.
    Version 1.0    ::    04-Jul-2016  :: Release.
    Transmogrified ::    RJ de Vries (3Bdesign)
.LINK
    http://ps1code.com
#>

    [cmdLetBinding( defaultParameterSetName = "percentage" )]
    param(
        [parameter( mandatory, position = 1, valueFromPipeline, parameterSetName = "percentage" )]
        [validateRange( 0, 100 )]
        [int]
        $percentage
        ,
        [parameter( mandatory, position = 1, valueFromPipeline, parameterSetName = "value" )]
        [validateRange( 0, [double]::maxValue )]
        [double]
        $value
        ,
        [parameter( position = 2, parameterSetName = "value" )]
        [alias( "max" )]
        [validateRange( 1, [double]::maxValue )]
        [double]
        $maximum
        ,
        [parameter( position = 3 )]
        [alias( "size", "length" )]
        [validateRange( 10, 100 )]
        [int]
        $width = 20
        ,
        [parameter( position = 4 )]
        [validateSet(
                "EqualThin"
            ,   "EqualThick1"
            ,   "EqualThick2"
            ,   "GrowingThin1"
            ,   "GrowingThin2"
            ,   "GrowingThick"
        )]
        [string]
        $style = "EqualThin"
        ,
        [parameter( position = 5 )]
        [validateRange( 0, 100 )]
        [int]
        $level2 = 60
        ,
        [parameter( position = 6 )]
        [validateRange( 0, 100 )]
        [validateScript( {
            if ( $_ -gt $level2 ) {
                $true
            } else {
                throw [System.Management.Automation.ValidationMetadataException] "Parameter [-level3] must be greater than [-level2]";
            }
        } )]
        [int]
        $level3 = 80
        ,
        [switch]
        $bare
        ,
        [switch]
        $draw
    )
    begin {
        function write-meter {
            param(
                [parameter( mandatory )]
                [string]
                $meter
                ,
                [string]
                $color = "white"
            )
            if ( $draw ) {
                $meter | write-host -noNewLine -foregroundColor ( [System.ConsoleColor]$color );
            } else {
                return $meter;
            }
        }

        if ( $PSboundParameters.containsKey( "value" ) ) {
            if ( $value -gt $maximum ) {
                throw "Parameter [-value] cannot be greater than [-maximum]";
            } else {
                $percentage = [int]( $value / $maximum * 100 );
            }
        }

        [string]$_bar = '';
    }
    process {
        if ( $bare ) {
            $_bar += write-meter -meter "[ "
        } else {
            [string]$_indent = " " * ( 3 - ( [string]$percentage ).length );
            $_bar += write-meter -meter ( '{0}{1}% [ ' -f $_indent, $percentage );
        }

        for ( $_i = 1; $_i -le ( $_value = ( [math]::round( $percentage * $width / 100 ) ) ); $_i++ ) {
            if ( $_i -le ( $level2 * $width / 100 ) ) {
                $_bar += write-meter -meter $__.gauge.bar.style.$style[0] -color "DarkGreen";
            } elseif ( $_i -le ( $level3 * $width / 100 ) ) {
                $_bar += write-meter -meter $__.gauge.bar.style.$style[1] -color "Yellow";
            } else {
                $_bar += write-meter -meter $__.gauge.bar.style.$style[2] -color "Red";
            }
        }
        for ( $_i = 1; $_i -le ( $_empty = $width - $_value ); $_i++ ) {
            $_bar += write-meter -meter $__.gauge.bar.style.$style[3]
        }
        $_bar += write-meter -meter " ]";
    }
    end {
        if ( -not $draw ) {
            return $_bar;
        }
    }
}
function out-log {
    process {
        if ( $log ) {
            $_ = $_.insert( 0, [datetime]::now.toString( "yyyyMMdd::HHmmss::" ) );
        #   $_ | write-host;
            $_ | out-file -filePath $log -encoding "ascii" -append;
        }
    }
}
function get-systemInformation {
    [CmdletBinding()]
    param(
        [parameter( position = 0 )]
        [validateNotNullOrEmpty()]
        [string[]]
        $computer
        ,
        [parameter( position = 1 )]
        [PScredential]
        [System.Management.Automation.CredentialAttribute()]
        $credential
    )
    begin {
        function get-intuneSyncTimestamp {
            if ( [string]$_authority = get-childItem -path "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts" -ea silentlyContinue | select-object -first 1 -expand name ) {
                $_ = join-path ( $_authority -replace "HKEY_LOCAL_MACHINE", "HKLM:" ) "Protected\ConnInfo";
                try {
                    if ( $_stamp = get-itemPropertyValue -path $_ -name "ServerLastAccessTime" -ea silentlyContinue ) {
                        'sync {0}' -f [datetime]::parseExact( $_stamp, "yyyyMMddTHHmmssZ", $null ).toString("yyyyMMdd HHmmss");
                    }
                } catch {}
            }
        }
        function get-owner {
            try {
                if ( -not ( $_ = get-itemPropertyValue -path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion" -name registeredOwner, registeredOrganization -ea silentlyContinue ) ) {
                    $_ = get-CIMinstance -className "Win32_OperatingSystem";
                    @(
                        $_.registeredOwner
                        $_.organization
                    )
                }
                if ( $_ ) {
                    ( $_ |? {
                        $_
                    } ) -join ' @ ';
                }
            } catch {}
        }
        function get-fqln {
            & whoami /upn 2> $null;
        }

        $_inventoryCommand = {
            $_os              = get-CIMinstance -className "Win32_OperatingSystem";
            $_bios            = get-CIMinstance -className "Win32_BIOS";
            $_system          = get-CIMinstance -className "Win32_ComputerSystem";
            $_chassis         = get-CIMinstance -className "Win32_SystemEnclosure";
            $_disk            = get-CIMinstance -className "Win32_LogicalDisk" |? { $_.deviceID -eq $_os.systemDrive };
            $_cpu             = get-CIMinstance -className "Win32_Processor";
            try {
                $_cli = '';
                if ( $_cli    = get-powerCLIversion ) {
                    $_cli     = ' | PowerCLI {0}' -f ( $_cli.major, $_cli.minor, $_cli.revision, $_cli.build -join '.' );
                }
            } catch {}
            $_domain          = ?0 ( ( [System.Net.NetworkInformation.IPGlobalProperties]::getIPglobalProperties() ) | select-object -expand domainName ), '';
            $_interface       = @();
            $_connection      = @();
            get-netIPconfiguration -detailed |? {
                $_.netAdapter.status -eq "up" -or
                ( $_.netAdapter.mediaConnectionState -eq "connected" -and $_.netAdapter.adminStatus -eq "up" )
            } |% {
                $_interface  += '{0} [{1}] aka "{2}"' -f @(
                    $_.interfaceAlias
                    $_.netAdapter.linkLayerAddress
                    $_.interfaceDescription
                );
                $_connection += '{0} -> {1} ({2}) @ {3} via "{4}"' -f @(
                    $_.IPv4address.IPaddress
                    $_.IPv4defaultGateway.nextHop
                    $_.netProfile.networkCategory
                    ?0 $_.NetProfile.IPv4Connectivity, $_.NetProfile.IPv6Connectivity
                    $_.netProfile.name
                );
            }
            @{
                user      = @{
                    name     = [environment]::getEnvironmentVariable( 'userName' )
                    domain   = [environment]::getEnvironmentVariable( 'userDomain' )
                    fqln     = get-fqln
                }
                system    = @{
                    product   = '{0} - installed {1}' -f $_os.caption, ( [datetime]$_os.installDate ).toString( 'yyyyMMdd' );
                    kernel    = 'NT {0} - {1}' -f $_os.version, $_os.OSarchitecture;
                #   uptime    = ( ( get-date ) - ( [datetime]$_os.lastBootUpTime ) ).toString( "%d' days '%h' hours '%m' minutes'" );
                    uptime    = ( ( get-date ) - ( [datetime]$_os.lastBootUpTime ) ).toString( "'up '%d'd'%h'h'%m'm'%s's'" );
                    shell     = 'PowerShell {0}.{1} {2}{3}' -f $PSversionTable.PSversion.major, $PSversionTable.PSversion.minor, $PSversionTable.PSedition, $_cli;
                    processes = get-process | measure-object | select-object -expand count;
                    serial    = $_bios.serialNumber
                    manufacturer = ?0 $_system.manufacturer, $_chassis.manufacturer
                    model     = ?0 $_system.model, $_chassis.model
                    chassis   = ?0 @(
                                    ( $__.system.chassis.getEnumerator() |? { $_.value -in $_chassis.chassisTypes } ).name -join ' | '
                                    "Unknown"
                                )
                    owner     = get-owner
                }
                processor = @{
                    name      = $_cpu.name -iReplace '(\(([CR]|TM)\)|CPU)', '' -replace '\s+', ' ';
                    load      = ( $_cpu | measure-object -sum loadPercentage ).sum
                }
                memory    = @{
                    free      = $_os.freePhysicalMemory;
                    used      = $_os.totalVisibleMemorySize - $_os.freePhysicalMemory;
                    size      = $_os.totalVisibleMemorySize;
                }
                disk      = @{
                    free      = $_disk.freeSpace;
                    used      = $_disk.size - $_disk.freeSpace;
                    size      = $_disk.size;
                }
                network   = @{
                    domain    = $_domain
                    interface = $_interface
                    connection= $_connection
                    sync      = get-intuneSyncTimestamp
                }
            };
        }
    }
    process {
        if ( $computer ) {
            $_session = $null;
            if ( $computer -ne $env:computerName ) {
                # Build Hash to be used for passing parameters to New-PSSession commandlet
                $_sessionArguments = @{
                    computerName = $computer
                    errorAction  = 'stop'
                };

                # Add optional parameters to hash
                if ( $credential ) {
                    $_sessionArguments.add( 'credential', $credential );
                }

                # Create remote powershell session
                try {
                    $_session = new-PSsession @_sessionArguments;
                } catch {
                    throw $_.exception.message;
                }
            }
        }
        # Build Hash to be used for passing parameters to 
        # Invoke-Command commandlet
        $_inventoryArguments = @{
            scriptBlock = $_inventoryCommand
            errorAction = 'stop'
        };
        
        # Add optional parameters to hash
        If ( $_session ) {
            $_inventoryArguments.add( 'session', $_session );
        }

        # Run ScriptBlock    
        try {
            invoke-command @_inventoryArguments;
        } catch {
            if ( $_session ) {
                remove-PSsession $_session;
            }
            throw $_.exception.message;
        }
    }
}
function show-console {
    $consolePtr = [Console.Window]::GetConsoleWindow();
    [Console.Window]::showWindow( $consolePtr, 5 );
}
function hide-console {
    $consolePtr = [Console.Window]::GetConsoleWindow();
    [Console.Window]::showWindow( $consolePtr, 0 );
}
function get-MSinfo {
    try {
        get-command "msinfo32.exe" -ea silentlyContinue | select-object -expand source;
    } catch {}
}
function invoke-MSinfo {
    if ( $_ = get-MSinfo ) {
        "  Opening Microsoft System Information using [{0}] ..." -f ( $_ -join '] [' ) | out-log;
        start-process -filePath $_;
        "  Done." | out-log;
    }
}
function get-certStore {
    try {
        # get-command "certlm" -ea silentlyContinue | select-object -expand source;
        get-command "certmgr" -ea silentlyContinue | select-object -expand source;
    } catch {}
}
function invoke-certificateStore {
    if ( $_ = get-certStore ) {
        "  Opening Certificate Store using [{0}] ..." -f ( $_ -join '] [' ) | out-log;
        start-process -filePath $_;
        "  Done." | out-log;
    }
}
function invoke-syncIntune {
#
#   https://techcommunity.microsoft.com/t5/microsoft-intune/is-it-really-impossible-to-force-an-intune-sync-from-the-command/m-p/3974461/highlight/true#M16905
#
#   $EnrollmentID = Get-ScheduledTask | Where-Object { $_.TaskPath -like "*Microsoft*Windows*EnterpriseMgmt\*" } | Select-Object -ExpandProperty TaskPath -Unique | Where-Object { $_ -like "*-*-*" } | Split-Path -Leaf
#
#   Start-Process -FilePath "C:\Windows\system32\deviceenroller.exe" -Wait -ArgumentList "/o $EnrollmentID /c /b"
#
    try {
        "  Synchronizing InTune ..." | out-log;
        $_binary = "DeviceEnroller.exe";
        if ( $_cmd = ( get-command $_binary -ea silentlyContinue ) | select-object -expand source ) {
            '    using binary [{0}]' -f $_cmd | out-log;
            $_filter = "*Microsoft*Windows*EnterpriseMgmt\*";
            if ( $_tasks = get-scheduledTask |? {
                $_.taskPath -like $_filter
            } ) {
                '    [{0}] tasks matching [{1}] found' -f $_tasks.count, $_filter | out-log;
                if ( $_enrollmentID = $_tasks | select-object -expand taskPath -unique |? {
                    $_ -like "*-*-*"
                } | split-path -leaf ) {
                    '    using enrollment ID [{0}]' -f $_enrollmentID | out-log;
                    $_arguments = @(
                        "/o"
                        $_enrollmentID
                        "/c"
                        "/b"
                    );
                    '    starting InTune synchronization using [{0}] [{1}] ...' -f $_cmd, ( $_arguments -join '] [' ) | out-log;
                    start-process -filePath $_cmd -wait -argumentList $_arguments;
                } else {
                    throw( "FAIL::Unable to determine enrollment ID" );
                }
            } else {
                throw( ( "FAIL::No tasks matching [{0}] found" -f $_filter ) );
            }
        } else {
            throw( ( "FAIL::Executable [{0}] not found" -f $_binary ) );
        }
        "  Done." | out-log;
        return $true;
    } catch {
        # # https://4sysops.com/archives/how-to-display-a-pop-up-message-box-with-powershell/
        # [System.Windows.MessageBox]::show( , , [System.Windows.MessageBoxButton]::Ok, [System.Windows.MessageBoxImage]::Warning );
        $_.exception.message | out-log;
        $null = [System.Windows.Forms.MessageBox]::show( $_.exception.message, "Synchronize InTune", [System.Windows.Forms.MessageBoxButtons]::Ok, [System.Windows.Forms.MessageBoxIcon]::Warning );
    }
}
function get-quickAssist {
    try {
        get-appXpackage -name 'MicrosoftCorporationII.QuickAssist' -ea silentlyContinue;
    } catch {}
}
function invoke-quickAssist {
    if ( $_ = get-quickAssist ) {
        $_ = @(
            'shell:AppsFolder\{0}!App' -f $_.packageFamilyName
        );
        "  Starting Quick Assist using [{0}] ..." -f ( $_ -join '] [' ) | out-log;
        start-process -filePath "explorer.exe" -argumentList $_;
        "  Done." | out-log;
    }
}
function show-output {
    param(
        [string[]]
        $content
        ,
        [string]
        $caption
    )
    try {
        $_canvas                    = [System.Windows.Forms.Form]@{
            text                    = $caption
            clientSize              = [System.Drawing.Size]::new( 800, 600 )
            backColor               = $background
            startPosition           = [System.Windows.Forms.FormStartPosition]::centerParent
        }
        $_lines                     = [System.Windows.Forms.TextBox]@{
            size                    = $_canvas.clientSize
            anchor                  = [System.Windows.Forms.AnchorStyles]::left -bor [System.Windows.Forms.AnchorStyles]::top -bor [System.Windows.Forms.AnchorStyles]::right -bor [System.Windows.Forms.AnchorStyles]::bottom;
            multiLine               = $true
            autoSize                = $true
            scrollBars              = [System.Windows.Forms.ScrollBars]::vertical
            readOnly                = $true
            text                    = $content -join "`r`n"
            font                    = [System.Drawing.Font]::new( [System.Drawing.FontFamily]::genericMonospace, 8 );
        }

        $_lines.add_keyDown( { judge-keyStroke -key $_ -target $this.parent } );
        [void]$_canvas.controls.add( $_lines );
        $_canvas.add_shown( {
            $_canvas.activate();
            $_lines.selectionLength = 0;
        } );

        [void]$_canvas.showDialog();
    } catch {
        'FAIL::Unable to show output dialog: [{0}]' -f $_.exception.message | out-log;
    }

}
function invoke-enrollment {
    try {
        $_cmd = "dsregcmd";
        $_ = @( "/status" );
        "  Checking enrollment status using [{0}] [{1}] ..." -f $_cmd, ( $_ -join '] [' ) | out-log;
        $_output = & $_cmd $_;
        "  Done." | out-log;
        if ( $_output ) {
            show-output -content $_output -caption "Enrollment status";
        }
    } catch {
        "FAIL::Enrollment check did not succeed: [{0}]" -f $_.exception.message | out-log;
    }
}
function copy-value {
    process {
        ?0 $this.tag, $this.text | set-clipBoard;
    }
}
function clone-element {
    param(
        [parameter( mandatory )]
        [validateNotNullOrEmpty()]
        $object
        ,
        [parameter( valueFromRemainingArguments )]
        $properties
    )

    try {
        $_clone = new-object -typeName $object.getType().fullName;
        $properties |% {
            if ( $_ -is [array] ) {
                $_ |% {
                    $_clone.$_ = $object.$_;
                }
            } else {
                $_clone.$_ = $object.$_;
            }
        }
        return $_clone;
    } catch {}
}
function judge-keyStroke {
    param(
        [parameter( mandatory )]
        $key
        ,
        $target = $this
    )
    begin {
        $_closeKeys = @(
            "Return"
            "Enter"
            "Escape"
        )
    }
    end {
        if ( $key.keyCode -in $_closeKeys ) {
            $target.close();
        }
    }
}
function get-indexedIcon {
    param(
        [parameter( mandatory, position = 0, valueFromPipelineByPropertyName )]
        $path
        ,
        [parameter( position = 1, valueFromPipelineByPropertyName )]
        $index = 0
        ,
        [switch]
        $small
    )
    try {
        $_large, $_small = 0, 0;
        #Call Win32 API Function for handles
        [Win32API.Icon]::extractIconEx( $path, $index, [ref]$_large, [ref]$_small, 1 ) | out-null;
        if ( $small ) {
            [System.Drawing.Icon]::FromHandle( $_small );
        } else {
            [System.Drawing.Icon]::FromHandle( $_large );
        }
    } catch {
    } finally {
        $_large, $_small |? {
            $_
        } |% {
            [void]( [Win32API.Icon]::deleteObject( $_ ) | out-null );
        }
    }
}
function get-image {
    param(
        [validateSet( "form", "portable", "fixed", "assist", "certStore", "intune", "enrollment" )]
        $name
    )
    begin {

        $_sources = @{
            form = @(
                        'AAABAAoAMDAQAAEABABoBgAApgAAACAgEAABAAQA6AIAAA4HAAAQEBAAAQAEACgBAAD2CQAAMDAAAAEACACoDgAAHgsAACAgAAABAAgAqAgAAMYZAAAQEAAAAQAIAGgFAABuIgAAAAAAAAEAIADDJQAA1icAADAwAAABACAAqCUAAJlNAAAgIAAAAQAgAKgQAABBcwAAEBAAAAEAIABoBAAA6YMAACgAAAAwAAAAYAAAAAEABAAAAAAAgAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAACAAAAAgIAAgAAAAIAAgACAgAAAgICAAMDAwAAAAP8AAP8AAAD//wD/AAAA/wD/AP//AAD///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHbGAAAAAAAAAAAAAAAAAAAAAAAAAAB2xsZGAAAAAAAAAAAAAAAAAAAAAAAAAHxsZwBwAAAAAAAAAAAAAAAAAAAAAAAABsZwAAAAAAAAAAAAAAAAAAAAAAAAAAAHxHAAAAAAAAAAAAAAAAAAAAAAAAAAAABsYAAAAABsZgAAAAAAAAAAAAAAAAAAAAbHAAAAAHxkxGwAAAAAAAAAAAAAAAAAAGxwAAAACMZGbGSAAAAAAAAAAAAAAAAAB8cAAAAABnAAAAdwAAAAAAAAAAAAAAAABkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAbAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAARwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB8YAAAAAAAAAAAAAAAAAAAAAAGQAAAAARkgAAAAABsYAAAAAB8ZwAAAAAMZIAAAHxsAAAAAARkbAAAAAfGTGAAAAAHxsAAAGRkAAAAAGxsZIAAAAxkbGAAAAAAZGcAAMbGAAAAAGxkxnAAAAZMZGAAAAAARsYAAGRsAAAAAHRkbAAAAAxmxsAAAAAAxkwAAExnBwAAAAxsZwAAAABGRIAAAAAAZGQAAGTGB8gAAAAHAAAAAAAIgAAAAAAATGwAAEZsCMZGxngAAAAAAAAAAAAAAAAAZGYAAGxmB2xsbGxGxwAAAAAAAAAAB8aAxsgAAATEAEZGRkbGTGxwAAAAAAAGxkQIRkAAAAdsAGxGxMZMZkbGgAAAAAbEbGwGxgAAAACEcGRsZkbGTGxkxgAAAMZGxkYGwAAAAAAGwIxkTGRkZGRGxsAACGxsZGAMcAAAAAAHaARsZGxsbGxsZGSADGRGTGB2AAAAAAAATAjGRsZEZEZGRsbHBkbGRgDGAAAAAAAAdnBkxkxsbGxsRkRsfGxkyAbAAAAAAAAADGAGxkZGRkZGxsZGxkbGcHxwAAAAAAAAAMYAZMbGxMbEZGxkZMZGB8YAAAAAAAAAAITABkZEZkZGxkTGxkZwjGAAAAAAAAAAAAhkAHxsbGxsZMZkbGAHxgAAAAAAAAAAAACMaAB0ZEZEbGTGSADGYAAAAAAAAAAAAAAATGAAB8bGxkZwAHxnAAAAAAAAAAAAAAAAB0bIAAAAAAAAfGYAAAAAAAAAAAAAAAAAAAfGxngACHxkbIAAAAAAAAAAAAAAAAAAAAAIbExkxsZIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA////////AAD///////8AAP///////wAA////////AAD///D///8AAP//AP///wAA//wN////AAD/+H////8AAP/h/////wAA/8f8P///AAD/j/AP//8AAP8f4Af//wAA/j/n5///AAD+f/////8AAPz//////wAA/P//////AAD5//////8AAPH/////nwAA4f8f8P+HAADD/g/gf4cAAMP8B+B/wwAAw/wH4H/DAADD/A/gf8MAAML+D/B/wwAAwj+/+f/DAADCAP///8MAAMIAD//4QwAA4wAB/+CHAADjAAB/gI8AAPEAAD8AnwAA+QAAHgGfAAD4gAAGAT8AAPyAAAIDPwAA/EAAAAJ/AAD+YAAABH8AAP8wAAAI/wAA/xgAABH/AAD/jAAAY/8AAP/DAADH/wAA//HgBw//AAD/+D/8P/8AAP/+A4B//wAA//+AA///AAD///////8AAP///////wAA////////AAD///////8AAP///////wAAKAAAACAAAABAAAAAAQAEAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAIAAAACAgACAAAAAgACAAICAAACAgIAAwMDAAAAA/wAA/wAAAP//AP8AAAD/AP8A//8AAP///wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAdsZAAAAAAAAAAAAAAAAAfGgAAAAAAAAAAAAAAAAABsAAAAAAAAAAAAAAAAAAAEgAAAfGcAAAAAAAAAAAAAYAAABsZMYAAAAAAAAAAABAAAAAAAAIAAAAAAAAAAAGcAAAAAAAAAAAAAAAAAAADAAAAAAAAAAAAAAAAAAAAGcAAAAAAAAAAAAAAHgAAATAAAAHxgAAAGwAAAB8YAB2YAAAjGSAAAxkYAAABsAAxsAAAHZMYAAGTGAAAAxnAGRgAAAMZgAAB8ZwAAAGRgBMcMcAAAAAAAAAAAAABMgAdsBkbGRoAAAAAAAAfAZgAAxgbGRsTGwAAAAAbGYMYAAAYHxsZGRkbAAADGTIdgAAAHwGRsbGxsZoAGRsYMAAAAAGBsZEZGRkxHDGxnhgAAAAB8BsbGxMZGxsZGwEAAAAAABoBGRkZsZGxkxgZwAAAAAADHDGxsRsZGRnB8AAAAAAAABnB8ZGxkxsAMYAAAAAAAAADGgAfHZ4AHZwAAAAAAAAAAAMZoAAB8bAAAAAAAAAAAAAAAjGxkaAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/////////////////g////h////z////58P//9+B//+//f//P////3////5///58/H5+OPg8Pzj4PD8Y/Hw/GJ///xiAf/k8gB/hPoAHwH5AAYL/QACA/yAABf+QAAn/yAAT/+QAZ//xgY///Dw///8A//////////////////KAAAABAAAAAgAAAAAQAEAAAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAIAAAACAgACAAAAAgACAAICAAACAgIAAwMDAAAAA/wAA/wAAAP//AP8AAAD/AP8A//8AAP///wAAAAAAAAAAAAAAAAcAAAAAAAB4AAAAAAAABwAMYAAAAABwAAAAAAAAAAAAAAAAAAAEAAZwBsAAYAYADGAHYABADIaHAAAAAMAGjExmAAfHcAB8ZkxoxmcAAHhMZMbGhwAABobGRnfAAAAAd3h3wAAAAAAAAAAAAAAAAAAAAAAAAP//AAD+/wAA8/8AAO5/AADf/wAA//8AALmdAAC5nQAAg/0AAIDhAADAAwAAwAMAAOAHAADwHwAA//8AAP//AAAoAAAAMAAAAGAAAAABAAgAAAAAAAAJAAAAAAAAAAAAAAABAAAAAQAAAAAAAKA4AAChOwQAojwFAKI+CACkPwkApEAKAKVCDQCmRA8ApkUQAKdHFACoRxMAqEgVAKlLGQCpTBoAqk4dAKxQHgCsUSEArVQjAK1UJACvWCoAsFgpALFbLACxXC4Asl4xALNhNQC0YTUAtGM4ALVlOgC3ZzwAt2g9ALdpQAC4a0EAuWxCALltRQC6cEgAvHJKALxzTAC9dE4AvndQAL54UgC/eVQAwHtWAMB9WQDCgF0AxINhAMSE'
                        'YQDFhmQAxohmAMeJaQDIi2oAyIxrAMiNbQDKj3AAypByAMuTdADLlHYAzJR2AMyVeADOmHsAzpl9AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALxQBFAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA6EQEBAQEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALAEBARQ1AAAnAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAQk1AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJAEBMQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAUAREAAAAAAAAAAAAaAQQUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABEBHQAAAAAAAAAAHQEBAQEBARQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGgEhAAAAAAAAAAAxAQEBAQEBAQE6AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwARgAAAAAAAAAAAAkMQAAAAAAACkpAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABQBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAaARAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABxEAAAAAAAAAAAkBATYAAAAAAAAAAAALARQAAAAAAAAAAAAvAQEkAAAAAAAAAAAADAEBNgAAAAAAKAEBAQAAAAAAAAAAAAEBAQEJAAAAAAAAACgBAQEBFAAAAAAAAAAAKAEBAQAAAAAAAQEBAQAAAAAAAAAAEQEBAQEBPAAAAAAAAAEBAQEBAQAAAAAAAAAAAAEBASkAAAAAAQEBEQAAAAAAAAAACQEBAQEBNQAAAAAAAAEBAQEBAQAAAAAAAAAAAAEBAQwAAAAAAQEBHQAAAAAAAAAAJAEBAQEBAAAAAAAAAAwBAQEBBQAAAAAAAAAAAAEBAQEAAAAAAQEBIQAoAAAAAAAAAAwBAQEkAAAAAAAAAAABAQEBPAAAAAAAAAAAAAEBAQEAAAAAAQEBIQAkBzYAAAAAAAAANQAAAAAAAAAAAAAAPDYAAAAAAAAAAAAAAAEBAQcAAAAAAQEBGAArAQEBARAYJDUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEBAREAAAAADAEBCQA2AQEBAQEBAQEBAQcfAAAAAAAAAAAAAAAAAAAAAAAkCQE6AAEBATwAAAAAAAEBAQAAAQEBAQEBAQEBAQEBAQQvAAAAAAAAAAAAAAAAEAEBAQEAPAEBBwAAAAAAACMBAQAAAQEBAQEBAQEBAQEBAQEBBDYAAAAAAAAAAB8BAQEBAQEAHwEHAAAAAAAAAAA2ASkAEAEBAQEBAQEBAQEBAQEBAQERAAAAAAAAFAEBAQEBAR0AAQkAAAAAAAAAAAAABwQANgEBAQEBAQEBAQEBAQEBAQEBAQAAAAA2AQEBAQEBAQAAASsAAAAAAAAAAAAAKwE8AAUBAQEBAQEBAQEBAQEBAQEBAQEvAAAQAQEBAQEBEQARAQAAAAAAAAAAAAAAAAELADABAQEBAQEBAQEBAQEBAQEBAQEBJAAHAQEBAQEBAAABGgAAAAAAAAAAAAAAACwBKwAQAQEBAQEBAQEBAQEBAQEBAQEBASQQAQEBAQEwAAkBAAAAAAAAAAAAAAAAAAAJAQAABwEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAR8AIQEvAAAAAAAAAAAAAAAAAAAAAQcAAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBGgA1AREAAAAAAAAAAAAAAAAAAAAAPAEJAAAMAQEBAQEBAQEBAQEBAQEBAQEBAQEpADYBCwAAAAAAAAAAAAAAAAAAAAAAADEBBwAAJAEBAQEBAQEBAQEBAQEBAQEBDAAALAEHAAAAAAAAAAAAAAAAAAAAAAAAAAA2AQE1AAAhAQEBAQEBAQEBAQEBAQw5AAAXAQ4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAkBEAAAAAAhCwEBAQEBBxApAAAAMAEBHQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAkAQEQNgAAAAAAAAAAAAAAACkBAQsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACEBAQEQITYAAAA8LxoHAQELNQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPBoBAQEBAQEBAQELJgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
                        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP///////wAA////////AAD///////8AAP///////wAA///w////AAD//wD///8AAP/8Df///wAA//h/////AAD/4f////8AAP/H/D///wAA/4/wD///AAD/H+AH//8AAP4/5+f//wAA/n//////AAD8//////8AAPz//////wAA+f//////AADx/////58AAOH/H/D/hwAAw/4P4H+HAADD/Afgf8MAAMP8B+B/wwAAw/wP4H/DAADC/g/wf8MAAMI/v/n/wwAAwgD////DAADCAA//+EMAAOMAAf/ghwAA4wAAf4CPAADxAAA/AJ8AAPkAAB4BnwAA+IAABgE/AAD8gAACAz8AAPxAAAACfwAA/mAAAAR/AAD/MAAACP8AAP8YAAAR/wAA/4wAAGP/AAD/wwAAx/8AAP/x4AcP/wAA//g//D//AAD//gOAf/8AAP//gAP//wAA////////AAD///////8AAP///////wAA////////AAD///////8AACgAAAAgAAAAQAAAAAEACAAAAAAAAAQAAAAAAAAAAAAAAAEAAAABAAAAAAAAoTkAAKI8BQCjPwgApD8JAKRACgClQgwApkQPAKdGEQCoRxMAqEkWAKlLGACqTBkAq04cAKxRHwCsUSAArVQjAK5WJgCvWCgAsFkqALFbLACxXC4Asl4xALNgMwC0YjUAtmU5ALdoPQC4aT8AuGtBALlsQgC6bkUAu3BHAL10TQC+d1AAv3lTAMB7VQDBfVkAwoBdAMSCXwDFhWMAxYZkAMaIZgDHiWgAyI1tAM2WeADOmHsAzpl9AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAsFAEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAjARIuAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABhQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEuAAAAAAAhBgMeAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAADAEBAQEMAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAACwAAAAAAAAAAAAAAAAAAAAAABcgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABIiAAAAAAAAAAAAAAAAAAAAAAAAAAAAACouAAAAAAADAQAAAAAAAB4BFwAAAAAAAAgGAAAAAAAAKgEXAAAAJAEBAAAAAAAuAQEBJwAAAAAGAQEBAAAAAAAAAQEAAAALAQwAAAAAACkBAQEgAAAAAAEBAQEAAAAAAAABASQAAAEBFAAAAAAAAAMBAQAAAAAAIwEBGQAAAAAAAAEBHgAACQEUAAElAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQEiAAAhAQgAAQEBAQEBECUAAAAAAAAAAAAAAAAnFAABAQAAAAABAQAMAQEBAQEBAQELAAAAAAAAAAAQAQEQAAEQAAAAAAAGACUBAQEBAQEBAQEBDAAAAAAAAQEBASsjFAAAAAAAACUZAAEBAQEBAQEBAQEBAS4AAAEBAQEBAAMAAAAAAAAAAAEAFgEBAQEBAQEBAQEBASUAAQEBASUsDAAAAAAAAAAAIxAAAQEBAQEBAQEBAQEBARYBAQEQAAEAAAAAAAAAAAAADCQAAQEBAQEBAQEBAQEBAQEBCwASIAAAAAAAAAAAAAAABikACAEBAQEBAQEBAQEBARcAFxAAAAAAAAAAAAAAAAAABh4AJwEBAQEBAQEBAQwAAA4UAAAAAAAAAAAAAAAAAAAAFgYsAAAnGxQUHisAACQBJAAAAAAAAAAAAAAAAAAAAAAAABABHi4AAAAAKxQBGQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAqFwgBAQweLgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/////////////////g////h////z////58P//9+B//+//f//P////3////5///58/H5+OPg8Pzj4PD8Y/Hw/GJ///xiAf/k8gB/hPoAHwH5AAYL/QACA/yAABf+QAAn/yAAT/+QAZ//xgY///Dw///8A//////////////////KAAAABAAAAAgAAAAAQAIAAAAAAAAAQAAAAAAAAAAAAAAAQAAAAEAAAAAAAChOQAAoz0GAKVCDACmRA8Ap0YRAKhJFQCpSxgAqk0bAK9WJgCwWisAsl4wALVjNwC3aT4AuWxCALxySgC9dU4Av3lTAMB7VgDBfFcAwn5aAMKAXADEgl8AxIRhAMWGZADGiGYAyItqAMmPbwDKj3AAy5FyAMuTdADMk3UAzJR2AM2WeADOmXwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
                        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP///wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABMAAAAAAAAAAAAAAAAVIQAAAAAAAAAAAAAAAAAPAAAABwcAAAAAAAAAAAARAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAUVAAALCQAAAAMAAAUAAAABDgAABwMAAAABAAADIA0ZGQAAAAAAAAAAAQAACyIBAQEBCQAAAAwBFw8AAAAaAwEBAQEBIBcBBxMAAAAAFSABAQEBAQEDASAhAAAAAAAPHAcBAQEBCiEUAAAAAAAAACAVHBwaIBEAAAAAAAAAAAAAAAAAAAAAAAAA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'
                        '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'
                        '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'
                        '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'
                        'GAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoTkAH6E5ANahOQD/oTkA36E5AD0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAChOQAHoTkAb6E5AMuhOQD4oTkA+qE5ANWhOQB/oTkADQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACgOAAZoTkA26A4AP6hOQDEoDgAFgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKA4ABGgOADHoTkA/6A4AP6gOAD+oTkA/6A4AP6gOAD+oTkA0aA4ABMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKE5AAqhOQDJoTkA/6E5AL6hOQAMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKE5AJahOQD/oTkA/6E5AP+hOQD+oTkA/6E5AP+hOQD/oTkA/6E5AIkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKA4AJigOAD+oTkA0aA4AA8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKA4ALegOACUoTkAS6A4ACCgOAANoTkAEKA4ACmgOABboTkAraA4AKgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoTkARqA4APygOADyoTkAJgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKA4AAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKA4AAoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACgOAADoTkA1aA4AP6gOABsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAChOQBdoTkA/6E5ANChOQAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKA4AAGgOADMoTkA/qA4AFYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKA4AAWhOQANAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoTkAMaA4AMqgOAD+oTkA4qA4AAYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKA4AAGgOAAJAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACgOAAEoTkABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKA4AEqhOQD1oDgA2aA4AGqhOQABAAAAAAAAAAAAAAAAAAAAAAAAAAChOQAioTkA7qE5AP+hOQD/oTkAjgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAChOQABoTkAeaE5AOyhOQD+oTkA0KE5AD4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoTkADqE5AJ6hOQD3oTkA/KE5ALahOQAeAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKE5AAihOQDroTkA/6E5AP+hOQCPAAAAAAAAAAAAAAAAAAAAAAAAAACgOACsoTkA/6A4AP6gOAD+oTkARQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACgOABvoTkA/6A4AP6gOAD+oTkA/6A4APGgOAAjAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoTkAq6A4AP6gOAD+oTkA/6A4AP6hOQDToDgABQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAChOQCroDgA/qA4AP6hOQD9oDgAPAAAAAAAAAAAAAAAAKA4ABmgOAD4oTkA/6A4AP6gOAD9oTkADQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACgOADboTkA/6A4AP6gOAD+oTkA/6A4AP6gOACCAAAAAAAAAAAAAAAAAAAAAAAAAACgOAAZoTkA/aA4AP6gOAD+oTkA/6A4AP6hOQD/oDgARQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAChOQByoDgA/qA4AP6hOQD/oDgAqQAAAAAAAAAAAAAAAKE5AFShOQD/oTkA/6E5AP+hOQDhAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKE5AAKhOQDuoTkA/6E5AP+hOQD/oTkA/6E5AP+hOQCXAAAAAAAAAAAAAAAAAAAAAAAAAAChOQAtoTkA/6E5AP+hOQD/oTkA/6E5AP+hOQD/oTkAWgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAChOQBIoTkA/6E5AP+hOQD/oTkA66E5AAQAAAAAAAAAAKA4AHagOAD+oTkA/6A4AP6gOADHAAAAAKA4ADoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACgOAC2oTkA/6A4AP6gOAD+oTkA/6A4AP6gOABdAAAAAAAAAAAAAAAAAAAAAAAAAACgOAAHoTkA66A4AP6gOAD+oTkA/6A4AP6hOQD8oDgAIwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAChOQAtoDgA/qA4AP6hOQD/oDgA/KA4ABoAAAAAAAAAAKA4AH6gOAD+oTkA/6A4AP6gOAC7AAAAAKA4AKygOAA0AAAAAAAAAAAAAAAAAAAAAAAAAACgOAAqoTkA66A4AP6gOAD+oTkA/6A4ALagOAAFAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoTkAV6A4APqgOAD+oTkA/6A4AP6hOQCBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAChOQAhoDgA/qA4AP6hOQD/oDgA/qA4AB4AAAAAAAAAAKE5AG2hOQD/oTkA/6E5AP+hOQC+AAAAAKE5ALWhOQD1oTkAi6E5ADqhOQAPoTkAAwAAAAAAAAAAoTkA'
                        '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'
                        '/6A4AOWgOACJoTkANKA4AASgOAAGoTkAH6A4ADagOABCoTkAQaA4ADKgOAAZoTkAAqA4ABGgOABSoTkAr6A4APihOQD/oDgA8KA4AHahOQAGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKE5AAGhOQBBoTkAvKE5AP2hOQD/oTkA/qE5AOihOQC3oTkAkKE5AHehOQBsoTkAb6E5AIChOQCeoTkAy6E5APahOQD/oTkA/6E5APGhOQCOoTkAGQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKA4ACigOACBoTkAzaA4APigOAD+oTkA/6A4AP6gOAD+oTkA/6A4AP6gOAD+oTkA/qA4AO2gOACxoTkAX6A4AA0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKA4ABKgOAA8oTkAX6A4AHWgOAB+oTkAfKA4AG2gOABSoTkAK6A4AAcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA////////AAD///////8AAP///////wAA///4////AAD//4B///8AAP/+AH///wAA//gA////AAD/4D////8AAP/A/////wAA/4PwD///AAD/B+AH//8AAP4P4Af//wAA/h/gB///AAD8P+/3//8AAPh//////wAA+H//////AADw/////z8AAOD/P/n/BwAAwfwP4H8HAADB/AfgP4MAAIH8B8A/gwAAg/gHwD+BAACC/AfAP4EAAIJ8B+B/gQAAggYP8P+BAACCAB///AMAAIIAA//gAwAAwAAA/4ADAADAAAA/AAcAAOAAAB4ADwAA8AAABgAfAAD4AAAAAB8AAPgAAAAAPwAA/AAAAAA/AAD8AAAAAH8AAP4AAAAAfwAA/wAAAAD/AAD/AAAAAf8AAP+AAAAD/wAA/+AAAAf/AAD/8AAAD/8AAP/4AAA//wAA//8AAP//AAD//+AH//8AAP///////wAA////////AAD///////8AAP///////wAAKAAAACAAAABAAAAAAQAgAAAAAACAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoTkADKE5AFGhOQBWAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAChOQAnoTkAh6E5ANOhOQD9oTkA/6E5APyhOQAHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAChOQAfoTkAqaE5AP2hOQDXoTkAgqE5AEWhOQBPoTkAUgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoTkAWqE5APKhOQDQoTkASAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKE5AHmhOQD9oTkAhKE5AAQAAAAAAAAAAAAAAAChOQAkoTkAr6E5APShOQD3oTkAuaE5ACsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAChOQBpoTkA/KE5AF8AAAAAAAAAAAAAAAAAAAAAoTkADaE5AOahOQD/oTkA/6E5AP+hOQD/oTkA5qE5AAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoTkAM6E5APmhOQB0AAAAAAAAAAAAAAAAAAAAAAAAAAChOQAhoTkAdKE5ACqhOQALoTkADqE5ADShOQCHoTkAFQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKE5AAGhOQDMoTkA'
                        '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'
                        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB/LQArnzgAd6E5AKhZHwABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAH0sABahOQCioTkAh584ADKhOQAoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAtABqhOQC1kTMAIgAAAACaNgBFoTkA6KE5AOudNwBGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAChOQCsjjIAHQAAAAAAAAAAjDEAJW4nAA1vJwAQljUAJwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACXNQBZoTkAcwAAAAAAAAAATxwAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB6KwAleysAJAAAAACHMAA1oTkA/YUvABkAAAAAeisAJKE5AO6hOQCgAAAAAFAcAAKhOQDPoTkA2GAiAAgAAAAAhi8AOqE5APJ8LAAZljUAeaE5AO6hOQAfAAAAAIcvADOhOQD8oTkAvQAAAACCLgAFoTkA6aE5APBjIwAOAAAAAF8hABChOQD/jDEAWZY1AGahOQDwoTkAiqE5AMGhOQCZoTkAmaE5AEmHLwACAAAAAHEoABR8LAAXAAAAAIQuADmcNwBLoTkA/4sxAERwJwAOoTkAz6E5AIOhOQD/oTkA/6E5AP+hOQD/oTkA2Zs2AE0AAAAAgi4AG6E5AMihOQD/oTkAnqE5ALRjIwACAAAAAI0yADWhOQCVoTkA86E5AP+hOQD/oTkA/6E5AP+hOQD+oTkAiKE5AJuhOQD/oTkA56E5AKmELgAZAAAAAAAAAAAAAAAAoTkAoKE5AJChOQD+oTkA/6E5AP+hOQD/oTkA/6E5AP+hOQDzoTkA+aE5AI2hOQCGAAAAAAAAAAAAAAAAAAAAAHorAA6hOQCxoTkAj6E5AOShOQD/oTkA/6E5AP+hOQD/oTkA1KE5AImhOQClcigABQAAAAAAAAAAAAAAAAAAAAAAAAAAdCkACqE5AIuhOQCjoTkAj6E5AI+hOQCQoTkAkKE5AKmhOQB5bSYAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAdSkAEpk2AFehOQB6oTkAeJg1AE9yKAAMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//8AAPh/AADg/wAAxD8AAMw/AACb+QAAEQgAABEIAAAAkAAAAEAAAIABAADAAwAAwAMAAOAHAAD4HwAA//8AAA=='            ) -join ''
            portable = @(
                        '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'
                        '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'
                        '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'
                        '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'
                        'Gh61LtgYF+7390c62to+/JtfPvg7a/UzTqYVcFuu+eDN2Xkez8+WLVv+0YXz5zt5+1IX+sTN+w/KnFnlcuE7zxavJx/tapoGeB1w97wz5+0CZzqFYOxga4fe7Gi301SqwwcPrOoYDV755D//w0l+RfPbk2kJ3Jar3v/xNJcr65tNS5u+vKRpcXaBtwBWNiA7d++V4oJ8ufzi86Sk2Kd333Igh1YfCIZ0DFwZJj+SeJE5pkRBu10Z0oHtY5NmyDVp1f5oS8uhT/7yn37y79bqZ7RMa+CpctUHbr553vwFdy9burS4vLxcr2jt3LlbXOkil150nsyqqYC7z5YQAruWtk7pR7eONxW+Ai8yqSWEzRsWe/oG9WZIBW1Z9cH9zRuH+tov/f//+lBIV54GMmOA23LF9TddVDt79oPLl6+YO3vWbL25Ye++/Qj0InLVFe+W8pIiuPs84UP8rR1d0o123lytsyQFOO/N7+sbEL4USG+2sFz44OBgrHn/3i8+dP+9D+iq00hmHHBbLrv2I/OKy8p+sWLlinMa6xvFPzCIYGtSg7qiwgKpLi+RAi8fFBTp7DHtvP5CggU8LycbZf16GZSQdRqPIU7Yv9vf3XbxP/y/n/SZb5peMmOB23Lx1X9alOf1PJjv8V07Fo2mc4x+QcNc4YAOgVdVlAqv3rkRhPVBKdq6uoWv6xwOj+ldNIl+9WBgYs/OnV//yQ/+7m5r19NSZjxwWy688k9caU7nPe7snE9luN3ZNZUVsnh+nVSUl0kurLkKFp+dmanWHhohbICGC2e6b9++Q52HOy66/6d3tlu7m7byRwM8Vd595YduzcjMus2VmVlUUuSTpoWNUje7VoduJ6fsXyqO83Ujk9u2brvre9+57RvWptNe/iiB2/LOyz/wgQyX+x5nVubs6opyefe558is2moFvn/fvo5Dhw9cct/ff/uE3TF6JsgfNXBbzn731TVpac4vVFVXvfeqyy/N7+xo/687bvvCF6zFM0hE/g+FXEJt9N+YKQAAAABJRU5ErkJggg=='
            ) -join ''
            fixed = @(
                        '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'
                        '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'
                        'qm2xZm8BBgYGahYg6yj8H9f/BCo1ADYDYYkldwCcEYB9n4kIIHrqNGnaqikSOmgAZvS/HQbwh6b7kANAwWdjLcACBjDNIk6vxgRU+CBOyXcA4a+wKZTYFaRImbGqWIZOyZVbUA/gOe+3kmDsxBgmyVhJM8zmuxvpvo90hyEhCpiCUd8W/2SM+MoKC6fwV5y1xG6L/pxMguCdRC2HEaw8L0OmnZU7G1cnfl9f92UGNTeCO5ABGDIHoz+mAOMWgPmE4i+F8GEAYAwMQEEEQAMYTSB+ZXaBjCKz8g0z8yTUZkYuRvxcCD5HCZ6WDbIkCOJ3EZshI6emW6ThmiaBEL+iwrfFnywjopNAooyYRBJkeBQjgES5/xmkiGP0f6LdbrlwrvIcAKYBs3SbW3+c/9MAWAjk7xx8/eLnT1RqAHRULgLSANj+2sZlAFgbmDQlVp5r1kUzu+xkj9ux3/vfjffpAmDcsmyJgwG4wWvLbXJxT/Ik1kU+7vNlKohdXmBRiM+dFEnM8iLs6ZdiKpCqCS5m5LdGf6f4LQNwpfJi1fwOZO8NjCnW0H/yijMQd7kPKHrDJIWiBxA6xe5kIj63iVl9QX7bAdFJi8Ka0xzfWyFicE4jfBuBe1qANGCkEbcbhUU9TAHGQvwu5tEASiH4EgieFMsoMqfIMJsUSugsUgBQ3TkzX0LIjDwA4YPg6cSIPwiMjMuSkbGZLgKnZkDs6Q6MAQRMARC/Ek3xMw08yQJp4RD/MJgA1wLufnK73PLnz6XTiANy/mzlBsA0YHYpZgRgGwB3AfwfN/YEqjQALgJ6G4BtBFwDCAgeJQ1adIcB7HGF/7dhN+CZLl9ptl/csiyJhQk4mbosR0jsslxl6rI8A0yA15hl+crUZQV4rQD3hRC8TZFMWWaIwTQgZnmJPNCQ6a926G+lxNopshj9neK3U21/2SoLOwEQ9vJyL/iaBYQftfycB06xV7y/gHWBi9I5/Izc06xI7m9RczwMw8MMKjMCz2nBPY2z5C/dcrEIeAYjfBk4jdG+FIJ3UqLiD50DZpMiS/iWAcyEAajw8yVYyYPo8yD4XJBjiIP4Y7MlMDbLIlMofuYGGNIhepImIyanGqJTLOGbGhAawLCoROQQgIkJWiPCKOCnyB79KQyg35iv0JuhagNgerptACNHjvT3Argx7etPVWoAbNHF/uxc9HNGAPZ9ZmaGDB4+Uuo0GwwD2Os2AGR9PdPlkC76TV2aZZGNqw1fJ7kS44LCz5MpS4FlADEwgClLAa8wATIZwjcUK1NXlGhu/20oB9a5v2PRz4T+jiIeO7UW22Z3ocCmRRD+TCzwRS0rt6Dg3Uxcdk4UmACJxEjvhAYQueyCBxPxedSKC3Jvy2K5vzp8GESlRuBaJ6g8GrizEfblIf7R88hpiJ2UYqQnED8wwgeziiTEZmYhRnwwowCiJ/kSROGDkdNIriEuRwm0DCBgaqa4mALxq/DTZYSKP02GR6eCFGXYJJIM4VP8SSr6IRD/kEgawCkZEHZC08f/46EtEj3/eJV1AMwC/AQlzswBYATARKCoqKi/QwI3949WagBc/GM3IBqArxNxaBA9eveTZ5oGIcWTEYDJ974VNf8tBh/TRb+pS7IkRsl2kIN7dBJyAuFPXmKxNB/Cz8fnyHAjMIHJSyF+AvFHM5NNKZbo5cVYFCyRZ/uwAs5s9ylViN8u0LkTlXXj480UYOKysx5ELoXgIX4Dhe6NEf4EJ0svSASIWnVBGgWekXubl8AEqsLLJLwMwWUGrojAOxrwXCSkAXSP4By/TEIh/lCsCRhKJWR2iWEWKVbxB8+0KYToCyH4AgsaQL6KPzCO5FrkQPAE2YBKloyIyYTgMwyTIX4wPJriT5NhMAAKfyiJSjZMTILwQWSiDCYTEjRlvHvoccz/t8m//2mrzFl+Aj0Kqq4DeOutt9QAOP/nbsCsWbNubhX/Hb99pQbAjL93333XpwHQELKwBtCmQyd5usk4GIC1BoDCj1uR+91qyDGZhvA/ZrFhyuJsN0tyZPJikguBG6KRdqqoCVD8xgCilUIDDIApq7YBTGKKK4hGyuvkZRBaI6s6ziV+a/R3jPyu6jzk5d/dOFue7ovoAlFA5FIn52QCDMBwHiK34D0EbkOxOwlfelFIxLJLMnrBBbmzWanc36oaPAzCYQgOM1Aj8FgnsI3AigY0hwB9CprkSK2B2NJbWIYFQXIaoj8twbNLJXgWKTGgdiBIKZKgGYTiL5SRSgGET/Hnq/gDSGyuRY6MgAGMgPhHxFD8WTJ8SqYMn5xhkQ7RA6QJk6GTUmVIVIphYrIyODLJIlEGQfxkSOQpaT3kKMrJt8m/PfS5vPhmCtqtVZ0GzFb1HPlpAFwM5FTV/3FjT6BSA/jqq6/0GCaG/KdOnaoQBaSkpEoLlAI/2hCVgCj80AgABnALdgS6h56UWIz8UxZnyuRFWRA7QcoqiF6UY4AJRMMEbPFPsk1gcT5ey0f+eoGDQlfOuua0Q/jMcY9aUqJMRg78AGT63YZad47+Feb9Wq5rVexpUY7J278DzT2GxJYhxD8LYYMl5yRCOW+A6M09xE4s0YfjXrFEH7bkotiE437i8m/ksf5n5L6Wp2ECleFlDi4zqGgElUcDnibwixa5Mn7hGYi+TAmCAQRB/MpMUqKMnFEMigwQfiCZVmCIK4Dw81X8I2IJuj5NzZXhMTkg2zAlS4ZNJpmG6AwZCvEPnUQoftQKoE5gMMQ/eKJFZLIMggEMmkBgABEJMhAwAmg24IgawL8+uEU+2YY04NLKIwCmAS9cuNBlAGwLxpoV/8eNPYEqDYDNQGwDoAnYcCfg5MlT0rBZC7TKmuoRAbDbT+8xCTryR8dnQuy4KhS/MYBJLnJxnytRKDqxmbQoH/cEBSkWE1GgQqIWs4AFhSsoYnFTgjz4EolZUap1/Hehu4+reYeO/r7Fb+ft/7od/i7s61P84S7O497GErsl+jBcnYIfv/iiGC4p40DY0kvSf+oFubsFxN+6EjyMwWEG3kZQaTRQMRK4q1GO9J+CsH+uLf7TMnIWgPhHqvBLJJBML7YokoBppNAA8Y+IzbfIk+FTSa4MiyE5MmwKyZahEL8hE8JncZBFVDqET/GnQfgwADAoMgVA/BOSZSDEPzCCJMrA8AQZEH5KjaBW1y+1nPz/PbhV9hzIRH9E98Gx3tmATAOeOXOmywB4LgDPJPR/3NgTqNQAKP4vvvjCpwFwCsA+AU3Qu+7Beku09FPrvpEByCYPw7DSy9F/UnyWF0hYiSc5FrkyMd4GJhCPjLb4fFCg1WkkEveRlgFMXISU13iAAhc3puiFJjABBTH3o3GHGoB36O8qx812F+0gT//uJnnSelSpzvPDkM2nUPyL+TmB4C3cYjeip9h9MX7RJfx538jvOpfDAMqqwTtCsMygEiPwnBJ4msA9jXOl0Qis7mMKMHJWmQSiVNnFjFJL/CUSAAMImEaKZASEPyLOIrZAhsMAhk8lxgCGQvwKxE+GTM6WIdEkyzApEyM9FoQhfmVimgwikUb8AyeQZBkA4SvhiUp/GED/MBgApgFPdUR5MRLJfvKHz5EAVKBpwJUdwcY04Ag0ZmX4z07AnTt31oHJ/3FjT6BSA+Bx1Tz2mQ+Xx2Q7IwBGBVu2fI4swJbyYH1PA+AUgOmfkzH6Ry0kWcpEJdsiB9cciVyY6wbij1TyLQpkwkIAA5gQX4jXCnEtsijGFVgVbxG4sgiG6bD9JhVhr98yADv09yV+V95+PrL3MHeOP4uR+xyEfV7GL7LgPcRPxqngbYzwx0LonnyDzw1hSy9L+7Dz2BE4Iw+0rsj9eM3gNAjbDLwjAmtaYEUDlZtArvyxMxJ5sBMQOBPMgAGAAIg/YDqB+KeRYoieFMlwElsow5QCGTaV5GPEh/inGIYg6WqIih+o+I0BDFbxZ8ogGMAgiH8QSoQp/oGRYEKqir8/xN8/wiI8CcJPlH5hJEH6jWcEkCj/0wpdg2AA/4JFwBKM/lWdwcgIgFt/tgGwDoD1Kv6PG3sClRrA+++/L1wHsA2AJmDDKcAWRAjNW7eU/6r1Cub/VucXRAA/xRQgDOWgFP/EBTZZ'
                        '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'
                        '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'
                        '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'
                        '7PfSBz//887/+wZwD3oFNg/iyF+i4u8w1mJMkbSHAbSH+NtD/O1HERhAqNsA2kH8SjBOIXaJP0PajEw3BKYBt/hbDEtG8VeKfLQ1S4oK8lX4RdrrP187/TCph1t97O+Xlpamra3Yfco+g4ImYE9B+Z5jc1ouSu+HCeyFCXCbmmcB7NixQ3eruGW9efNmYSdrnhv48ccf++AjvAY+Qjstfv2TTfLJZ1vk483bZOuuvbL/6CnZicXHCYtfxgL0UqxPxavYh0XNBfMQyc7zNICajP72yO8Y/Z1hf/CMFeiBsRbNbF+C+Ndp2K/Cr4SQGTQAKxKwTIAmVRMDqMwcfE4BnAZAE3AawSl0Bx4aECjNOwQj8cezEvDpzof1PDieBjNIT4Qxh0O4esWzbTTbR7ONNDrJalfZqCzF1W+OvecUtqJiSyqCnHZ2qXF1rGHzCquO3VXWihJXVLsZUPnG6jfANFgmwvSbUm5xFldyDqH/eek7BWAKQBPoFY2VfuT/6y5AZQbAFXpMA2gAjw5kFGBE3Dvuex3VDZbI42gAtgn8TXrh9V6xNj9Iz6n4WZjIU8NYKuxMCvrxI4B7m+bJY70xx4cBUPztVfgWmAKoAUD87ULzLHJxzcGx4wDibwvxtw0iOBJuJMVvDKA1xN86gKRi5E+RVhj9mw1LkTWvnUJY/zUKyk6quClyip2jPoXPVt7c8nPu+/Oer6empcuhr3EQTVKynDiVgAghSVKTEyUpgRHC13IEpkBD2Ldvn5oBKwK5dU0joAl89NFH8iFyVXi1cZoCX9sEo9iNSIKL2vw3scBt1+49aGk+G+cYzsU5hnP0Wr0BmPLcigt/FUN/W/w64s9bg3MvNqDDNUZ8h/BDZqxCuA8wsivW5x6m4DCBEEQLNTGAGkcAbLG8ZMkSVwRgG4B9pTsPHDpMmncMgQG4KwFvx35u7e5H8ODMQRB6IISeCoP+8OwTT2AArvbR2kqaXWXRXFIxveZcvee0Dx1bUlmdabRLDbvV2CDFlXXsSjEq3VDhprDc1a58YwFMmfSFCRjKwVkDTKAPTKAPDKDPlAtKv6mXpHEQ9vxbmTRgYwKei4BauMMCHhgAc/rbYiGPEQCjgd4Y0c3I7hS6ue/pZOoP0iOGfC+9pnwnnaKYGehMDbYN4MfZBTB9EPLkV23zsABYCuEbA2hHRpNCCL0AGANoS0JyQY4hOFvaQPxtRpJMaQ3xKxS/ZQCtRqRC/CnScniyNB2aLLHxeyAyI0JbjBQhBUrY2ouiZRhPITL7lILW3acjh1Gnv1+Wv71NZqxDRd/ijTjVCItiSK5Z+ep7Oj2wzYKGQWgqnE4QGg7T2e1aFq5fMYqwIwhGFfw+GhIjDRrIpk2fyBtvv4tDS2Ya8fsyAA3/zRTAhP5VzP09Rn9rwQ7CHz/3BZxutUFH/dFVCd82AOfVaQaWCagBjImpdApw3WsA33zzjSxbtky3APnQKhgAHLNHn95Sv80kcyqwoxlI4/5H9fy3ATwJRklx94jXfvFoGc320egfz06ydlfZAXaDSbSbYt85N+hEw5ZU7E6DRhWmYYXB1K9btewwAK1ws+g7qcwUvrD6DQbQJ/qM9FbKcQ9gAIZz0nvyeYsLuF7AmsAlebC71cK7ggGYnQDbAJjG+7se38IArknvqTABjOikJwTec6pb9D1w78Yt/u5TvpduMAD+zEP9EAFUqAuwDcDRLcijJqBmuwC2AdzTJFfahJoIwCX+UZb4Q2EAoQj/LfG3gQG0Cc4BFD9Q8WdB+DCAwAxpFZgurTDyKyr+VIg/RVrQAIYko7st0sk3+QrFq36NhsFwniP78xvQSRf1+6Gx8Tg+/mV5efN+iV/3ujy/aqV+D02EUwBOBTglcJoIRc73MAXOtQVOL2gMFD3XHGgGTHfn30dj+gS89c57HgZgRn9Q4/Dfc8/fXvgLnr4cXa1fwJmWL6PWH8LnHN+e3+sKv2PER0jPsL4inlGBvUYQMmu19IEBsNGJ98cN7QKwGcjKlStdBkATsOFDZQjWoUtXGADPBPQ0gKYDjun5b66TYKyDIdx94mkAbB2drp1k+yvsKosGk2w0afWcM40n2YASvejQj64vO9PYXWrYsGIiG1dYNexazsqyVta2o8pNsYpeWAADM+g9yRhAL72WW5xFyH8OnDfACHpFwwSmXJTuUezia0cAJhOQW4GmnRdLd00EQO7vcEXqB1/V+XyPmO90VDfYQv+rdI+x+QH3P0D0FD6Y/J10Bd0mX5PmY6/K/e3sPgGmPLiqegBXh6BKmoM4E4GcBvBMfyz0IQKwR/62MIC2EL8Skg9wroCKP1daB+WAbIie2OLPhPgzpGVAurQckWYB8WMK0IIGgPl/k8HJMnWhbwOg4D744AOPEN0Ozzl/37Rpk/D47z0wgJdefkWWrV4rwZExMnvVRiQEHZT4F16T2TgOnFGE77m+MRhn+G9HIfx7aQqMDBiVOH/+k0+MAQyc4I4AamwAlST9MOQPw4gfvXQjwv2XzH6+taqvBuAhfiP6UHyPYbUDpyGYaYE9JeD0odeoSXL8VKLPaX51JlBhDYAlmOwFYEcATgPQFVkcF9apa1d5usUcDwNgSmc7pHcOsE+B0as5GII94rVPPFtGs3W0tpCGCUSwnTS6ysIETKNJq+ccrn3ZgkpbUZE8V5ea3uhWw6YVbF5hGlhY5awwAHeZqyl60QIYZMCRngQG0GtSudJz0llwDlwA56WHwvuLagINR3Jr0CrC8d4KdEYBNIJOV6Rr9DXpgdG8u/K9BcXu5HsI3iL6O+miXJMuMIDuMWwc6jSA6sJ/61gx2wCqaRV+Hzsioy/iHzphi29cibQdVQQc4kf43wYG0CYYZyW6xA8DgPhbkcAsYIsfBjDCNgAK3xZ/ijRXA0iRqZgCOCMACo4jLkNznjHBcJ+hP0dxip6tvV577TV55ZVXZP369RoBqAE8v1aCIqeqATA3wDYA/oyngD/RBUAn3gZBI+DiNg3AHvnd5gMDeNuXAVS1AOh76y8I233hEP6U5RtxpN2LaHizyrV9Z2/r2QI2c32n+B3Ch7jdRuDbBGgAXUaEScnp8h8nAuDciuevc7Sn2D0jgEMIubZLl25d5fGm8SgF/sKjG1BbZHf1w1lvegoMD4PQE2F4OAT7xAP2i7daR5s20mwnTdhc0mo0yYaT6DvXBy2o2IZK21Fpayo0qFDQrAJNK9i8gjXsNAAtadXSVmJVurHwZSILYAjED3pMPAMjKMcV8Bp1FqI/hxGfnJfuMIAeUZdwhQlMviR/7GmH3s51AGcUYCKBBzAVeHzwt7qoxxHdjOq8OgTP++jvLdGjL8Akcs3iKl6/KnXYMqxd9aO/6RFYTTWg1RnIHv2NAeTIPU2wqDe6GFOBIlAICiB8QvHnY8TPk1ZBuRB9jgXEj/k/DaBlQCbIkBYQvyFNxd98GIH4MfdvPhTbf4NgAAvcBkDxU3TX88F5uYkAXpDgibEwgFc0JXjJhrdlcfxCNQiKnUJ+88031ThefvllHbx4//rrrwuPt3PuCvB77QigWgPwXgCswfw/CPP+iPnrMF15RUf8UIzw7kw/7PlXMfp7jPoU/uw1DmwjsE3AHQW4DaCs0gigqiigQgRAh2QIxrk/DcAJTeFTuHiXHt3kkcYsBXYbACu6eqDfO89+68NTYJRkPRzC1SMe7aJN62iALrLsJms6yjoaTLLhJPrOGdCDDgZgt6bqqR1qTLMK07zC1LCzpNWACrcJqHRjtZtWvRGrCCbSGEB3pdzirHSbeM7ivHSDCXRD+E9oAp0jEYa38RUFeK0FwATuwyJem/CrED1GdI7qrhHejPSdbSD8ThC+gsW/TmgQ0mki+VabhZgpho/Rn+sRnJZ4tAr33RvQmQbsbQB3N8qW+oMheEQArUMKQQFGfAhfxZ/vEn9LGEBLjPwtAwnFTyj+DGkO8TcfnmZhGcBQYwDNhiRJ40FJEscI4FMTivtq21WdGXBuv/6ll2XJitUSEBYt03GizoZP98jzr3+IvIADlf44j9e6ePGicCpLsdMUbBPgv4ULgjWKAK7DANiWK2LBWold+aqu6odie8+Z+ONK3vE2'
                        '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'
                        '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'
                        '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'
                        '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'
                        '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'
                        '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'
                        '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'
                        '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'
                        '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'
                        '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'
                        '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'
                        'NcfEMKDOo/PLASnVPzoh86IJ0UTg3hTJkEaAVhDJQFqBzIOUCKQNjJQIlI0ov4BMAs1GlBYg+xgQQwCaIQlQADiRCfIGSEsGTJgEOCwxA5CoCsVh/zMguW4kAPq5HgHwHWDFXOrvX5fl/u+77mbbdfVNdsDr8x251ed1uPPvsHv/j/r///Pb3/Hru5/AVXfIODqMY7iX80IA+ADQAIoJ4KTtOXCVtS9aY30OsAEnH7adnnDTudhJgJaQwTDtoJAQouZQI4eaeVBMFPVIhO+6fb7CFbO7hvwuKnmn1b0wHdEu6XPGpgiAiEApDWC08fu83zPA8XYjCQFydMJJnYelAD6fAT7HqQCE7LsYiove95gjIMdInNYrO5x9MXlI2YJxq/Rf/V4JQ1wvRiU0E41OVgHKGI1IC1dI44AM5CfQfafmQR4RRN9AWSKI0YLUOai5CGkasggAcEHYilSQdEQuAmBCA1AFZ8gCAuF8XAP/BCSfmgBFII2AlYaGmfH+m47bo595zO7/+KfsQV8E48FHvGDL13zRVwf1sqVLMuKhj4tyPKR1QACENblHCA5S47liu+22W22v1wNoX7Aqy/3f4yYA2zkZAaStmBDOIoWEGGrAzzMnyu/rdh/A5Z40xXvB/wKpqfQa/a4JbSkBYAKQNIQPoKETcCxJQDn7WdrnYOnqqNoDfBrAh62UN85giJKzDFh42ZoHEAEjr3uaw47KlFay4RiOR+pyDjnoOLdShiEZJR/Jwy1NABKIUYrUgchxkIG0FMig0bMV+Qc0J0E5+Jr6qypFmARKa451CWK+gMwATUTCPMMByOBC+itMSQox8wY0Z4D9mp6MOoqvAcLRys2pBlAPqKnUBti8Ayb77HaNY9u2rU48vnS3Zz8yN4L3Qj9GzS/v/PIBkPGIExCHZAp+PvMcu/cfsnY3AXrcNt9z9fuz7RzXCLLmJJBPBkFDKNASpDl0+/mGmRDyLYxw2+0OwInT2rOcDXIyML8gNzSvSAD0jUqrEQmQE5AoAAlBDZ2AY0ECSDIYV+BHsgN2bkiNfRADxwgUUpUVQpOEVlku5ePn5eTLQ85gzGsAQo3vcaDRtPiIav1p2TNNfwVskALX5j64J9UO4H5hXO6fQYcJwCDWCrXyb8hZqSq5HJcSncyDGD6URlCPCDR7L9bp41k0OSnPKYjUziMApDrvjQEG0JH6hALZ4gDUUnGQBWaEwM+1MV/QokQASCg+NwJrSgIKacX4vvo1Ly8j/j4minFtEQDaDYDHrxHbrbfeYns89bjNC230rlhve9wE6HUTYIgARAQJIZQlBcCfZ0KMaJ8TTJebIXNdg7h06qwhAtA74P1C/IxRBJR8bAhWogCo/2QFKi245QTAhckeY0AjFVHpawtX/CQjAcJu7OdlKrsuzrzLm34bJVuaDKN025hzH9Ny0/9jmq6y6dgiKWnK5RdBRELQysKQgQZ8jMnK5oXUZB4Aep5ZkQv+14o59YhA5kEMIRYRgTQd1Sykv2LikLQAlchOCQAJKQeg1H9UTSYgIXkJA0ryQBJIVfqdPuKaaEloNICdiUh8LwJITQCBtJVbrS8RNYAU/HyG7HbtO2htC1ZYt9voezz1uNvVdZyCc7z4Rq0NagNF20EtYTgprMvOc7YZkWgO8jOcta1pHiQodXqWYtuClfbeSdNslYdkwRaaC5EXfDrgAQJmbCCQZP9jVtfWgTij/pdKBBqtBsDL56YANaoI0i9KPl4ON8r3gEhTbVWBl8ErFVZJLiqrFUNaSntVdpsGMI4rGtIKj7UaA1gt5rorqUXFNJTXzwAXMUAKqukHIaAdMPAVi41kIK1ADi5eCP2AeaBsLeUtpBoBfaMwYmoe5BFBNHtQj2nclyYp0Y/cN/kBkICcgXkEALBl/6MBYO8zjRjvP30otTMFv8qG85w8H2QhAkCDkf+mlYBPz50SANJSUQ3MG7VbbnGH475D1jZvpTvZ+jMTAKkNAcRWmgycJAD9XJfYMh/qmxHD/QxzFjnoRTQemuzyc83sXmwTLp9i69ZvzMYvxMxYx4cj9V8VrRhzteXkajkAzA2I0v+cEACqo+KS6QQepBrSghsW4JEiSmBBistOVWKJ4rjEpok/k55KsgmSCScPYSpNcWXSDCmsSCF5rfFck52mxmcaAxV1FfuW3+Dp5lzk3bOPY/B209kwrcgAM0IOL5J0pBXIb6DEDCRiqhFE00B5DRAk5KCZc3k+kBg5iEQQowaqd6C+ldYU6xQwYOhfEQDkiSRBA1C6MhoAYMf5Rz/Q36quxLvgHfH8mEYCuPLT0fDo5/NNAACBe4smQAR+JIDdew/Y7PnLrcc97XuP3Oj1Bvqtw52CHQtjG04IRRqCJH5DrSFHm+jwfR2LB68DkXi7or3XJk6e4b4QnwLt70EL8eK34T3ybhl/jAPGGxol4wnpL+efMgALJwONVuKnv2ewyOmmQhKqHqMSXACewYhEj7YoTA3D8bDYnQAaG5QGOAEqefJ4ohmoSG2IgvMg4QAnUk/lv5CGcuwJIDG0xn0RR6Uj+T1Ap3NxhqFqcS0m40AOTJIhXx9JwnG6lpYYl2MxL0NLDkNekBKfCIkqbRPG5sWphp6SZ1JnqIgghg9j5IBnVPlyaQHpHIJ6BCANgElITD1GC0CTwjGoSkL0L/0KmUNWkjjEm5E4/CYSgMKhUUojodMkqhiO1ezMZrecC1BAAJAcJJ5PALfYzoGDNrtvhYfo1tluJwCIoN1V7owEYmtACNjphA3PaAv1zIeEUAavQzSiY37tupfN6LS2rh7b5TgQCWuBXbRfMASe0KAxt2X7a7agpD8TgeJfy30AgERz6AG5Fmdky41r3jtAx7GEFEaSM68dby//MwA5DzYaqg5SBzUcqcbgw95hAMruBFiSrkoRhgVxOOJ7oGnqJKqR9iGxVCkY9VWZZajxDCBArRl/OJIAAyoxYTGIAZLgeVCzRTzcoxyHchoCXC0LrnkOihrIR6JoiPwDeVED7ktaVV4IMS5qwr0rjThGBYoIAJAAdCb+UGEoEi3PCMmq+IdKdENi9F8MNfFOIwHkAZvBKjLl/dJ/nDNOHpLvoBligGAiAaDdQABoNrHdfPMJ27lnv832HPu57pWHALrc7oYAYjuLDEQMg6QA+JH6qelQ/DmSy+C13BHZwXXnr7AJU9utd8GS7B1EyY+mhsCT4w/hRr/xvJiZjH3GtmYCyvN/TgkAgAJgAE6no7aowg1SXAUt+J/jkOZIfgYYUhXpjTqNqsuAZyDIlwC7aaYTDKciCCqAoKSmsuWS4nGqN0i8FLsJ7ymkwTUBJZIsLoGOOsy98wyoythn7BMRAD6IgGdhMPKiAC8vS1OX5R9Q7jbX0uQkLasVcyGQiHHOgTQC5TkoHKr5BGgB0SEImUUCUJ485IbWg3aD3Y+2g93PZwad1E3ZmtwTxAWBMtjoL0maSADcjyI8UZpD2PQb/hcAibklMyzLBfCxg8bBWJBjS4U/ZCLFZK44bVxTx9GGogaQgp/PPN8uNwFm9S531X+d7Tp8g/XvcKfgvOUZENsdlFlLCCFqCBDGHHwGhdrCqizPYKjpnL5t82tkzX0QXGd233K7ZEqbLV+1Ogu74qtCo5bkB/yx4CsYgSARJlpRCTJW7v+IyoKPlSkAqBj0qmuHKo+9TYcjSVC1VYwSYKC+MEgAg4AgkCuEAcA1pzkWNxire653Hq1SxD3gUUWDAKTcLwDEjMAkyAaTx67RDBjAONwgAa3YqxqEkIiIgMEMmDSBAzNAi5fIN6Da+kp7TScfxXkHmmdA/ytXIDVzYi4ABMA7gQAYZEz8wexC6uBIBfz4C7R4Cvcu8KNdpeCnHzEBULuJAiAM0roO0oQY3JCiokEAVus50peQAqYXpgg+HqQhYwgQQEQKvabgzyMAyI3f8l5iO+EzCnfs3WezvNgo4FuzbZ/tvOpYNjGpRgBpGySEQVIA/AA/T1sY2pcB/sx52uYB+OVDjUKnfD91Tl8W5lu/sRZ1oX94B7wXyBDtWZI/Jv1AjJBxtPuV9ps3rltuAuiiSFLAoqm4CoMhNQA4IQqkOGylMkaqZXauQT5SIhEpcN88'
                        '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'
                        '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'
            ) -join ''
            intune = @(
                        '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'
                        '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A181p/ns6Q2A3d2vPKrvqyDo/faVrz/7vlJ9/0orvDKovv/5LXSPvWL9K9/0kwAYGgKg+TgGgEEz77BRfY85Eztj9qseMyd0xoxxHTG99zFlTHvfO/zqwjvVx/ij2ltt/JtYFXfVqZbV3/fk3r/7ab0/A9UnOtXPRfWzsmDyK48jp3bF0dOqx+i+x+umj+67pXH1AIaGAACAhAQAACQkAAAgIQEAAAkJAABISAAAQEICAAASEgAAkJAAAICEBAAAJCQAACAhAQAACbkbIIPmfSdNLUdwyL5+66ZydEDuBjg03A2w+QgAoKkIgKEhAJqPXQAAkJAAAICEBAAAJCQAACAhAQAACQkAAEhIAABAQgIAABISAACQkCsBAk3lUK4EyNBwJcB68gkAACQkAAAgIQEAAAkJAABISAAAQEICAAASEgAAkJAAAICEXAgIaCqNciGgwbo4Ts/Vy8tR7QzWvyuDyycAAJCQAACAhAQAACQkAAAgIQcBAk1l3Ki22HrpsnJcO7/yRz8pRwNyw8cWlaPacRBgPQkAoOk0wpHxWezq7olRn7qxHFMDdgEAMGSe3rqrHFETAgBoOs9u212OGCFrH95ajqgJAQA0nQ9c90A5YoR89DsPlyNqQgAATefv7t0c923cWY4ZZt+647l4/qU95ZiaEABA06mObH7Tf7srdu1xjPNIuW/jjvjtr91fjqkRAQA0pU3b98S8i2+NzTu8Ax1utz2+PU78wp3R3SPA6kwAAE3rma27Y/K5N8cf3vBUucQQeceX74mTvnhnvLRrb7lEzbgOAJDGiiMmxOnHTY55h3WWSwxQd+92/t5nd8Q312+Ku5/ZUS5TYwIAABKyCwAAEhIAAJCQAACAhAQAACQkAAAgIQEAAAkJAABISAAAQEICAAASEgAAkJAAAICEBAAAJCQAACAhAQAACQkAAEhIAABAQgIAABISAACQkAAAgIQEAAAkJAAAICEBAAAJCQAASEgAAEBCAgAAEhIAAJCQAACAhAQAACQkAAAgIQEAAAkJAABISAAAQEICAAASEgAAkJAAAICEBAAAJCQAACAhAQAACQkAAEhIAABAQgIAABISAACQkAAAgIQEAAAkJAAAICEBAAAJCQAASEgAAEBCAgAAEhIAAJCQAACAhAQAACQkAAAgIQEAAAkJAABISAAAQEICAAASEgAAkJAAAICEBAAAJCQAACAhAQAACQkAAEhIAABAQgIAABISAACQkAAAgIQEAAAkJAAAICEBAAAJCQAASEgAAEBCAgAAEhIAAJCQAACAhAQAACQkAAAgIQEAAAkJAABISAAAQEICAAASEgAAkJAAAICEBAAAJCQAACAhAQAACQkAAEhIAABAQgIAABISAACQkAAAgIQEAAAkJAAAICEBAAAJCQAASEgAAEBCAgAAEhIAAJCQAACAhAQAACQkAAAgIQEAAAkJAABISAAAQEICAAASEgAAkJAAAICEBAAAJCQAACAhAQAACQkAAEhIAABAQgIAABISAACQkAAAgIQEAAAkJAAAICEBAAAJCQAASEgAAEBCAgAAEhIAAJCQAACAhAQAACQkAAAgIQEAAAkJAABI6P8BuZN9sK1ItmUAAAAASUVORK5CYIIgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg'
                        'ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA='
            ) -join ''
        };
        if ( $_ = get-quickAssist ) {
            $_sources.assist = ( [xml]( get-content -literalPath ( join-path $_.installLocation "AppXmanifest.xml" ) ) ).package.applications.application.executable;
            $_sources.assist = get-item -literalPath ( join-path $_.installLocation $_sources.assist );
        }
        if ( $_ = get-certStore ) {
            $_sources.certStore = get-item -literalPath $_;
        }
        $_sources.enrollment = @(
            get-item -literalPath ( join-path ( [environment]::getEnvironmentVariable( "SystemRoot" ) ) "System32\imageres.dll" )
            # index number in the dll resource section
            213
        )
    }
    end {
        if ( $_sources.$name ) {
            if ( $_sources.$name -is [System.IO.FileSystemInfo] -or $_sources.$name -is [array] ) {
                $_file = $_sources.$name | select-object -first 1;
                if ( test-path -literalPath $_file ) {
                    if ( $_sources.$name -is [array] ) {
                        new-object PSobject -property @{
                            "path"  = $_file.fullName
                            "index" = $_sources.$name[1]
                        };
                    } else {
                        $_file.fullName;
                    }
                } else {
                    $null
                }
            } else {
                [System.IO.Stream]$_buffer = [System.IO.MemoryStream]::new( [System.Convert]::fromBase64String( $_sources.$name ) );
                # https://stackoverflow.com/a/72205381
                [void]$_buffer.seek( 0, [System.IO.SeekOrigin]::begin );
                $_buffer;
            }
        }
    }
}
function show-full {
    begin {

        try {
            if ( $test ) {
                $_inventory = @{};
            } else {
                $_inventory = get-systemInformation;
            }
        } catch {
            'FAIL::Unable to retrieve system information: [{0}]' -f $_.exception.message | out-log;
            return;
        }

        [System.Windows.Forms.Application]::enableVisualStyles();
        #TODO::Parameterize more GUI elements, enable styling to an extent
        $_margin                        = 10;
        $_iconSize                      = 48;

        try {
            $_canvas                    = [System.Windows.Forms.Form]@{
                clientSize              = [System.Drawing.Size]::new( $width, $_margin + 0 + $_margin )
                backColor               = $background
                text                    = $me
                maximizeBox             = $false
                minimizeBox             = $false
                formBorderStyle         = [System.Windows.Forms.BorderStyle]::fixedSingle
                startPosition           = [System.Windows.Forms.FormStartPosition]::manual
                opacity                 = $transparency
                icon                    = [System.Drawing.Icon]::new( ( get-image -name "form" ) )
                keyPreview              = $true
            }
            if ( $position -eq "center" ) {
                $_canvas.startPosition  = $__.dialog.position.$position;
            } else {
                $_canvas.location       = $__.dialog.position.$position;
            }
        } catch {
            'FAIL::Unable to create main dialog canvas: [{0}]' -f $_.exception.message | out-log;
            return;
        }

        try {
            $_hover = [System.Windows.Forms.ToolTip]@{
                toolTipIcon             = [System.Windows.Forms.ToolTipIcon]::none      # ::info
                isBalloon               = $false
                showAlways              = $true
            }

            $_label = [System.Windows.Forms.Label]@{
                location                = [System.Drawing.Point]::new( $_margin, $_margin )
                size                    = [System.Drawing.Size]::new( 90, 14 )
                foreColor               = [System.Drawing.Color]::darkOliveGreen
            };
            $_label.font                = [System.Drawing.Font]::new( $_label.font.name, 8, $_label.font.style );

            $_value = [System.Windows.Forms.TextBox]@{
                location                = [System.Drawing.Point]::new( $_label.Location.x + $_label.width + 10, $_label.Location.y )
                readonly                = $true
                borderStyle             = "none"
                font                    = $_label.font
                foreColor               = [System.Drawing.Color]::black
                backColor               = '#E5D9D5'
                autoSize                = $false
                wordWrap                = $false
            };
            $_value.size                = [System.Drawing.Size]::new( $_canvas.clientSize.width - $_value.location.x - $_margin - $_iconSize - $_margin, $_label.height )
        } catch {
            'FAIL::Unable to create template controls: [{0}]' -f $_.exception.message | out-log;
            return;
        }

        $_arePortable = @(
            "Portable"
            "Laptop"
            "Notebook"
            "Hand Held"
            "Sub Notebook"
            "Tablet"
            "Detachable"
        );

        try {
            $_model = [System.Windows.Forms.PictureBox]@{
                location                = [System.Drawing.Point]::new( $_canvas.clientSize.width - $_margin - $_iconSize, $_margin )
                size                    = [System.Drawing.Size]::new( $_iconSize, $_iconSize )
                sizeMode                = [System.Windows.Forms.PictureBoxSizeMode]::stretchImage
                image                   = [System.Drawing.Image]::fromStream( ( get-image -name ( ?: { $_inventory.system.chassis -in $_arePortable } { "portable" } { "fixed" } ) ) )
                cursor                  = [System.Windows.Forms.Cursors]::hand
                borderStyle             = [System.Windows.Forms.BorderStyle]::fixedSingle
                padding                 = 8
                tag                     = "System Information"
            }
            $_model.add_click( {
                invoke-MSinfo;
            } );

            $_assist                    = clone-element $_model 'location','size','sizeMode','cursor', 'borderStyle', 'padding';
            $_assist.size               = [System.Drawing.Size]::new( $_iconSize, $_iconSize )
            $_assist.top                = $_model.top + $_model.height + $_margin;
            $_assist.left               = $_model.left + $_model.width - $_assist.width;
            $_assist.image              = [System.Drawing.Icon]::extractAssociatedIcon( ( get-image -name "assist" ) );
            $_assist.tag                = "Start Quick Assist"
            $_assist.add_click( {
                invoke-quickAssist;
            } );

            $_certStore                 = clone-element $_assist 'location','size','sizeMode','cursor', 'borderStyle', 'padding';
            $_certStore.top             = $_assist.top + $_assist.height + $_margin;
            $_certStore.image           = [System.Drawing.Icon]::extractAssociatedIcon( ( get-image -name "certStore" ) );
            $_certStore.tag             = "Show Certificates"
            $_certStore.add_click( {
                invoke-certificateStore;
            } );

            $_syncIntune                = clone-element $_certStore 'location','size','sizeMode','cursor', 'borderStyle', 'padding';
            $_syncIntune.top            = $_certStore.top + $_certStore.height + $_margin;
            $_syncIntune.image          = [System.Drawing.Image]::fromStream( ( get-image -name "intune" ) );
            $_syncIntune.tag            = "Synchronize InTune"
            $_syncIntune.add_click( {
                if ( invoke-syncIntune ) {
                    $global:_refresh = $true;
                    $_canvas.close();
                }
            } );

            $_enrollment                = clone-element $_syncIntune 'location','size','sizeMode','cursor', 'borderStyle', 'padding';
            $_enrollment.top            = $_syncIntune.top + $_syncIntune.height + $_margin;
            $_enrollment.image          = ( get-image -name "enrollment" | get-indexedIcon ).toBitmap()
            $_enrollment.tag            = "Check enrollment status"
            $_enrollment.add_click( {
                invoke-enrollment;
            } );
        } catch {
            'FAIL::Unable to create tool controls: [{0}]' -f $_.exception.message | out-log;
        }

        if ( $test ) {
            $_table                 = @();
        } else {
            $_table                 = @(
                                        @{
                                            label = 'now'
                                            value = {
                                                ( @(
                                                    get-date -format 'yyyyMMdd HHmmss'
                                                    $_inventory.system.uptime
                                                    $_inventory.network.sync
                                                ) |? {
                                                    $_
                                                } ) -join ' - '
                                            }
                                        }
                                        @{
                                            label = 'user'
                                            value = {
                                                @(
                                                    ( @(
                                                        $_inventory.user.domain
                                                        $_inventory.user.name
                                                    ) |? {
                                                        $_
                                                    } ) -join '\'
                                                    $_inventory.user.fqln
                                                ) -join ' - '
                                            }
                                        }
                                        @{
                                            label = 'host'
                                            sel   = $true
                                            value = {
                                                @(
                                                    [environment]::getEnvironmentVariable( 'computerName' )
                                                    ( '.' + $_inventory.network.domain ) -replace '\.$', ''
                                                ) -join ''
                                            }
                                        }
                                        @{
                                            label = 'owner'
                                            value = {
                                                $_inventory.system.owner
                                            }
                                        }
                                        @{
                                            label = 'model'
                                            value = (
                                                '{0} ({1}) by {2}' -f @(
                                                    $_inventory.system.model
                                                    $_inventory.system.serial
                                                    $_inventory.system.manufacturer
                                                )
                                            )
                                        }
                                        @{
                                            label = 'OS'
                                            value = $_inventory.system.product
                                        }
                                        @{
                                            label = 'kernel'
                                            value = {
                                                @(
                                                    $_inventory.system.kernel
                                                    $_inventory.system.shell
                                                ) -join ' - '
                                            }
                                        }
                                        @{
                                            label = 'CPU'
                                            value = $_inventory.processor.name
                                        }
                                        @{
                                            label = 'interface'
                                            value = (
                                                $_inventory.network.interface -join "`r`n"
                                            )
                                        }
                                        @{
                                            label = 'connection'
                                            value = (
                                                $_inventory.network.connection -join "`r`n"
                                            )
                                        }
                                        @{
                                            label = 'current load'
                                            pre   = $true
                                            value = @(
                                                { out-gauge -value $_inventory.processor.load -maximum 100 }
                                                '{0,7} processes' -f $_inventory.system.processes
                                            )
                                        }
                                        @{
                                            label = 'memory'
                                            pre   = $true
                                            value = @(
                                                { out-gauge -value $_inventory.memory.used -maximum $_inventory.memory.size }
                                                '{0,7} / {1,7}' -f @(
                                                    ( 1024 * $_inventory.memory.used | convertTo-humanReadable -pad ' ' ) -replace '[^\d]+', ''
                                                    1024 * $_inventory.memory.size | convertTo-humanReadable -pad ' ' -unit 'B'
                                                )
                                            )
                                        }
                                        @{
                                            label = 'system volume'
                                            pre   = $true
                                            value = @(
                                                { out-gauge -value $_inventory.disk.used -maximum $_inventory.disk.size }
                                                '{0,7} / {1,7}' -f @(
                                                    ( $_inventory.disk.used | convertTo-humanReadable -pad ' ' ) -replace '[^\d]+', ''
                                                    $_inventory.disk.size | convertTo-humanReadable -pad ' ' -unit 'B'
                                                )
                                            )
                                        }
            );
        }
    }
    end {
        if ( -not ( $_canvas ) ) {
            'FAIL::Dialog canvas not initialized, unable to proceed' | out-log;
            return;
        }
        $_position = $_label.Location.y;

        $_table |% {

            try {
                $_lbl           = clone-element $_label 'size','font','foreColor';
                $_lbl.location  = [System.Drawing.Point]::new( $_label.location.x, $_position );
                $_lbl.text      = $_.label;

                $_val           = clone-element $_value 'size','font','readonly','foreColor', 'backColor', 'borderStyle', 'autoSize', 'wordWrap';
                if ( $_.pre ) {
                    $_val.font  = [System.Drawing.Font]::new( [System.Drawing.FontFamily]::genericMonospace, 8 );
                }
                if ( $_.sel ) {
                    $_val.tabIndex = 0;
                }
                $_val.location  = [System.Drawing.Point]::new( $_value.location.x, $_position );
                $_val.text      = forEach ( $_item in $_.value ) {
                    if ( $_item -is [scriptBlock] ) {
                        & $_item;
                    } else {
                        $_item;
                    }
                }
                if ( $_lines = [regex]::new( "`r`n" ).matches( $_val.text ).count ) {
                    $_val.multiLine = $true;
                    $_val.height   *= ( $_lines + 1 );
                    $_lbl.height    = $_val.height;
                }

                $_lbl.add_click( {
                    copy-value;
                } );
                $_lbl.tag       = $_val.text;
                [void]$_canvas.controls.add( $_lbl );

                $_val.add_click( {
                    copy-value;
                    $this.selectAll();
                } );
                [void]$_canvas.controls.add( $_val );

                $_hover.setToolTip( $_lbl, $_val.text );

                $_position += $_val.height + [int]( $_value.height * 0.3 )
            } catch {
                'FAIL::Unable to furnish dialog with label/value: [{0}]' -f $_.exception.message | out-log;
            }
        }

        $_canvas.clientSize = [System.Drawing.Size]::new( $_canvas.clientSize.width, $_position + $_margin );

        forEach( $_tool in @(
            $_model
            $_assist
            $_certStore
            $_syncIntune
            $_enrollment
        ) ) {
            try {
                [void]$_canvas.controls.add( $_tool );
                $_hover.setToolTip( $_tool, $_tool.tag );
                $_canvas.clientSize = [System.Drawing.Size]::new( $_canvas.clientSize.width, [math]::max( $_canvas.clientSize.height, $_tool.location.y + $_tool.height + $_margin ) );
            } catch {
                'FAIL::Unable to furnish dialog with tool [{0}]: [{1}]' -f $_tool.tag, $_.exception.message | out-log;
            }
        }

        #TODO::Adjust height calculating total tool icon height and margins
        # if ( $_canvas.height -lt $height ) {
        #     $_canvas.Height = $height;
        # }

        $_canvas.add_shown( {
            $_canvas.activate()
        } );
        $_canvas.add_keyDown( {
            judge-keyStroke -key $_;
        } );

        '  Showing full' | out-log;
        [void]$_canvas.showDialog();

    }
}
function show-minimal {
    try {
        $_domain                    = ?0 ( ( [System.Net.NetworkInformation.IPGlobalProperties]::getIPglobalProperties() ) | select-object -expand domainName ), '';
        $_host                      = @(
                                        [environment]::getEnvironmentVariable( 'computerName' )
                                        ( '.' + $_domain ) -replace '\.$', ''
                                    ) -join '';

        $_canvas                    = [System.Windows.Forms.Form]@{
            clientSize              = [System.Drawing.Size]::new( 200, 20 )
            backColor               = $background
            maximizeBox             = $false
            minimizeBox             = $false
            formBorderStyle         = [System.Windows.Forms.BorderStyle]::none
            startPosition           = [System.Windows.Forms.FormStartPosition]::manual
            opacity                 = $transparency
            icon                    = [System.Drawing.Icon]::new( ( get-image -name "form" ) )
        }
        $_canvas.location           = [System.Drawing.Point]::new( [System.Windows.Forms.Screen]::primaryScreen.WorkingArea.width - $_canvas.width, [System.Windows.Forms.Screen]::primaryScreen.WorkingArea.height - $_canvas.height );

        $_label                     = [System.Windows.Forms.Label]@{
            size                    = $_canvas.clientSize
            anchor                  = [System.Windows.Forms.AnchorStyles]::left -bor [System.Windows.Forms.AnchorStyles]::top -bor [System.Windows.Forms.AnchorStyles]::right -bor [System.Windows.Forms.AnchorStyles]::bottom;
            text                    = $_host
        }

        $_label.add_click( {
            copy-value;
        } );
        [void]$_canvas.controls.add( $_label );
        $_canvas.add_shown( {
            $_canvas.activate();
        } );
        $_canvas.add_formClosing( {
            '  Closing minimalist' | out-log
        } );

        '  Showing minimalist' | out-log;
        [void]$_canvas.showDialog();

    } catch {
        'FAIL::Unable to create main dialog canvas: [{0}]' -f $_.exception.message | out-log;
        return;
    }
}

# endregion routines

# region init

$_refresh = $false;

# endregion init

# region aliases

# region globalAliases

set-alias -force -option allScope -scope global -name '?:'                      -value invoke-ternary                    -description 'Ternary operator filter';
set-alias -force -option allScope -scope global -name '?0'                      -value coalesce                          -description 'Coalesce filter';

# endregion globalAliases

# endregion aliases

# region main
"Start {0} v{1} ..." -f $me, $__.version | out-log;
[void]( hide-console );
if ( $minimalist ) {
    [void]( show-minimal );
} else {
    do {
        $_refresh = $false;
        [void]( show-full );
    } while( $_refresh );
}
"End. {0}" -f $bye | out-log;
if ( $minimalist ) {
    exit;
} else {
    [void]( show-console );
}
# endregion main
