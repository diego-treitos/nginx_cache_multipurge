-- vim: set ts=2 sw=2 sts=2 et:
--
--  Author: Diego Blanco <diego.blanco@treitos.com>
-- Version: 0.1

local md5 = require 'md5'

--------------------------------------------------------------------------------
---------------------------------- globals -------------------------------------
--------------------------------------------------------------------------------
--
-- Variable to control whether to run or not.
local cmp_run_if = ngx.var.cmp_run_if or ''
-- Value of the cache_key variable. i.e. $proxy_cache_key
local cmp_cache_key = ngx.var.cmp_cache_key
-- Path where the cache files are stored. i.e. /var/www/cache
local cmp_cache_path = ngx.var.cmp_cache_path
-- Initial segment of the URL to be stripped to get the URL to purge. i.e. /purge/dynamic
local cmp_cache_strip = ngx.var.cmp_cache_strip or ''
-- Use keyfinder helper instead of grep
local cmp_cache_keyfinder = ngx.var.cmp_cache_keyfinder or ''
-- path to keyfinder binary
local cmp_cache_keyfinder_path = ngx.var.cmp_cache_keyfinder_path or "nginx_cache_keyfinder"

------ patch global variables
-- check if we won't purge
if cmp_run_if == '' or cmp_run_if == '0' then ngx.exit( ngx.OK ) end
-- remove tailing slash from cmp_cache_strip
cmp_cache_strip = cmp_cache_strip:gsub( '/$', '' )
-- url to be purged
local cmp_uri = ngx.var.request_uri:gsub( cmp_cache_strip:gsub("%p", "%%%1"), "" )
-- change the cache key to use the right url
cmp_cache_key = cmp_cache_key:gsub( ngx.var.request_uri:gsub("%p", "%%%1"), cmp_uri )


--------------------------------------------------------------------------------
---------------------------------- helpers -------------------------------------
--------------------------------------------------------------------------------
--
--------------------- sanitize string to be used as a shell command parameter --
function safe_shell_command_param( string_with_user_input )
  -- prevent command injection
  return "'"..string_with_user_input:gsub( "%'", "'\"'\"'" ).."'"
end


--------------------------------------------------------------------------------
------------------------------ purge functions ---------------------------------
--------------------------------------------------------------------------------
--
----------------------------------------------------------- purge all entries --
function purge_all()
  os.execute( "rm -rd '"..cmp_cache_path.."'/*" )
end

------------------------------------------------------ purge matching entries --
function purge_multi( uri )
  if cmp_cache_keyfinder == "" or cmp_cache_keyfinder == "0" then -- use grep
    -- escape special characters for grep
    local cache_key_re = cmp_cache_key:gsub( "([%.%[%]])", "\\%1" )
    cache_key_re = cache_key_re:gsub( cmp_uri:gsub("%p","%%%1"), uri..".*" )
    local safe_grep_param = safe_shell_command_param( "^KEY: "..cache_key_re )

    os.execute( "grep -Raslm1  "..safe_grep_param.." "..cmp_cache_path.." | xargs -r rm -f" )
  else -- use keyfinder
    local uri_start = cmp_cache_key:find(cmp_uri, 1, true) or cmp_cache_key:len()
    local prefix = safe_shell_command_param( cmp_cache_key:sub(1, uri_start-1)..uri )
    local suffix = " "..safe_shell_command_param( cmp_cache_key:sub(uri_start + cmp_uri:len()) )
    os.execute(cmp_cache_keyfinder_path.." "..cmp_cache_path.." "..prefix..suffix.." -d")
  end
end

-------------------------------------------------------- purge specific entry --
function purge_one()
  local cache_key_md5 = md5.sumhexa( cmp_cache_key )
  os.execute( "find '"..cmp_cache_path.."' -name '"..cache_key_md5.."' -type f -exec rm {} + -quit" )
end


--------------------------------------------------------------------------------
------------------------------------- main -------------------------------------
--------------------------------------------------------------------------------
--
-- check if last character of the request_uri is a *
if string.sub( cmp_uri, -1 ) == '*' then
  if cmp_uri == '/*' then
    purge_all()
  else
    -- uri is request_uri without the trailing *
    local uri = string.sub( cmp_uri, 1, -2 )
    purge_multi( uri )
  end
else
  purge_one()
end

ngx.exit( ngx.HTTP_NO_CONTENT ) -- Status code if everything works
