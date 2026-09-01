[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$ThreadId,

    [Parameter()]
    [string]$DatabasePath = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.t3\userdata\state.sqlite')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    [Guid]::Parse($ThreadId) | Out-Null
}
catch {
    throw "T3 thread ID is not a UUID: $ThreadId"
}

if (-not (Test-Path -LiteralPath $DatabasePath -PathType Leaf)) {
    throw "T3 state database was not found: $DatabasePath"
}

$typeDefinition = @'
using System;
using System.Runtime.InteropServices;

public static class T3SessionResolverWinSqlite
{
    public const int SqliteOpenReadOnly = 0x00000001;
    public const int SqliteRow = 100;

    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_open_v2(
        [MarshalAs(UnmanagedType.LPUTF8Str)] string filename,
        out IntPtr database,
        int flags,
        IntPtr vfs);

    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_close(IntPtr database);

    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_prepare_v2(
        IntPtr database,
        [MarshalAs(UnmanagedType.LPUTF8Str)] string sql,
        int length,
        out IntPtr statement,
        IntPtr tail);

    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_bind_text(
        IntPtr statement,
        int index,
        [MarshalAs(UnmanagedType.LPUTF8Str)] string value,
        int length,
        IntPtr destructor);

    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_step(IntPtr statement);

    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_finalize(IntPtr statement);

    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr sqlite3_errmsg(IntPtr database);

    [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr sqlite3_column_text(IntPtr statement, int column);

    public static string Text(IntPtr pointer)
    {
        return pointer == IntPtr.Zero ? null : Marshal.PtrToStringUTF8(pointer);
    }
}
'@

try {
    [T3SessionResolverWinSqlite] | Out-Null
}
catch {
    Add-Type -TypeDefinition $typeDefinition
}

function Get-SqliteText {
    param(
        [Parameter(Mandatory = $true)] [IntPtr]$Statement,
        [Parameter(Mandatory = $true)] [int]$Column
    )

    return [T3SessionResolverWinSqlite]::Text(
        [T3SessionResolverWinSqlite]::sqlite3_column_text($Statement, $Column)
    )
}

$database = [IntPtr]::Zero
$statement = [IntPtr]::Zero
$sqliteTransient = [IntPtr](-1)
$sql = @'
SELECT
    r.thread_id,
    r.provider_name,
    r.adapter_key,
    r.runtime_mode,
    r.status,
    r.last_seen_at,
    r.resume_cursor_json,
    r.runtime_payload_json,
    s.status,
    s.provider_session_id,
    s.provider_thread_id,
    t.project_id,
    t.branch,
    t.worktree_path
FROM provider_session_runtime AS r
LEFT JOIN projection_thread_sessions AS s ON s.thread_id = r.thread_id
LEFT JOIN projection_threads AS t ON t.thread_id = r.thread_id
WHERE r.thread_id = ?
'@

try {
    $result = [T3SessionResolverWinSqlite]::sqlite3_open_v2(
        [IO.Path]::GetFullPath($DatabasePath),
        [ref]$database,
        [T3SessionResolverWinSqlite]::SqliteOpenReadOnly,
        [IntPtr]::Zero
    )
    if ($result -ne 0) {
        $message = [T3SessionResolverWinSqlite]::Text(
            [T3SessionResolverWinSqlite]::sqlite3_errmsg($database)
        )
        throw "Could not open T3 state database read-only: $message"
    }

    $result = [T3SessionResolverWinSqlite]::sqlite3_prepare_v2(
        $database,
        $sql,
        -1,
        [ref]$statement,
        [IntPtr]::Zero
    )
    if ($result -ne 0) {
        $message = [T3SessionResolverWinSqlite]::Text(
            [T3SessionResolverWinSqlite]::sqlite3_errmsg($database)
        )
        throw "Could not query T3 state database: $message"
    }

    $result = [T3SessionResolverWinSqlite]::sqlite3_bind_text(
        $statement,
        1,
        $ThreadId,
        -1,
        $sqliteTransient
    )
    if ($result -ne 0) {
        throw "Could not bind T3 thread ID to the read-only query. SQLite error: $result"
    }

    $result = [T3SessionResolverWinSqlite]::sqlite3_step($statement)
    if ($result -ne [T3SessionResolverWinSqlite]::SqliteRow) {
        if ($result -eq 101) {
            throw "No T3 provider runtime was found for thread: $ThreadId"
        }
        $message = [T3SessionResolverWinSqlite]::Text(
            [T3SessionResolverWinSqlite]::sqlite3_errmsg($database)
        )
        throw "Could not read T3 provider runtime: $message"
    }

    $cursorJson = Get-SqliteText -Statement $statement -Column 6
    $cursor = if ($cursorJson) { $cursorJson | ConvertFrom-Json } else { $null }
    $nativeId = if ($cursor) { [string]$cursor.threadId } else { $null }
    if ([string]::IsNullOrWhiteSpace($nativeId)) {
        throw "T3 has no provider-native resume cursor for thread: $ThreadId"
    }

    $payloadJson = Get-SqliteText -Statement $statement -Column 7
    $payload = if ($payloadJson) { $payloadJson | ConvertFrom-Json } else { $null }

    [pscustomobject]@{
        t3_thread_id = Get-SqliteText -Statement $statement -Column 0
        provider = Get-SqliteText -Statement $statement -Column 1
        adapter = Get-SqliteText -Statement $statement -Column 2
        native_session_id = $nativeId
        runtime_mode = Get-SqliteText -Statement $statement -Column 3
        runtime_status = Get-SqliteText -Statement $statement -Column 4
        projection_status = Get-SqliteText -Statement $statement -Column 8
        last_seen_at = Get-SqliteText -Statement $statement -Column 5
        provider_session_id = Get-SqliteText -Statement $statement -Column 9
        provider_thread_id = Get-SqliteText -Statement $statement -Column 10
        cwd = if ($payload) { [string]$payload.cwd } else { $null }
        project_id = Get-SqliteText -Statement $statement -Column 11
        branch = Get-SqliteText -Statement $statement -Column 12
        worktree_path = Get-SqliteText -Statement $statement -Column 13
        source = 'provider_session_runtime.resume_cursor_json.threadId'
    } | ConvertTo-Json -Depth 5
}
finally {
    if ($statement -ne [IntPtr]::Zero) {
        [T3SessionResolverWinSqlite]::sqlite3_finalize($statement) | Out-Null
    }
    if ($database -ne [IntPtr]::Zero) {
        [T3SessionResolverWinSqlite]::sqlite3_close($database) | Out-Null
    }
}
