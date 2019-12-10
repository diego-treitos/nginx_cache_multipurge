-- vim: set ts=2 sw=2 sts=2 et:
--
-- Diego Blanco <diego.blanco@treitos.com>

-- LIMITATIONS:
--   * cache_key must contain request_uri
--   * urls with $ ' " | ` characters will not work


local md5 = require 'md5'

--------------------------------------------------------------------------------
---------------------------------- globals -------------------------------------
--------------------------------------------------------------------------------
--
-- Value of the cache_key parameter. i.e. $scheme$host$uri
local cmp_cache_key = ngx.var.cmp_cache_key
-- Path where the cache files are stored. i.e. /var/www/cache
local cmp_cache_path = ngx.var.cmp_cache_path
-- Initial segment of the URL to be stripped to get the URL to purge. i.e. /purge/dynamic
local cmp_cache_strip = ngx.var.cmp_cache_strip or ''


--------------------------------------------------------------------------------
---------------------------------- helpers -------------------------------------
--------------------------------------------------------------------------------
--
------------------------------------------------------ check if a file exists --
function file_exists( name )
  local f=io.open( name, 'r' )
  if f~=nil then io.close(f) return true else return false end
end

------------------------------------------------ check if uri is a valid path --
function validate( uri )
  -- selection of characters allowed in URL to prevent RCE
  -- NOT allowed: ' " $ ` | 
  local valid_url_re = "^/[a-z0-9\\./_~!&\\(\\)\\*\\+,;=:%@\\-]+$"
  if ngx.re.match( uri , valid_url_re, 'ijo') then return true else return false end
end

---------------------------------------- replace string once without patterns --
function string_replace( target, match, replace )
  local match_s, match_e = target:find( match )
  if match_s then
    match_s = match_s-1
    match_e = match_e+1
    return target:sub( 1, match_s ) .. replace .. target:sub( match_e )
  else
    return target
  end
end


--------------------------------------------------------------------------------
------------------------------ purge functions ---------------------------------
--------------------------------------------------------------------------------
--
----------------------------------------------------------- purge all entries --
function purge_all()
  -- os.execute( "rm -rd '"..cmp_cache_path.."/*'" )
  os.execute( "echo '"..cmp_cache_path.."/*' >> /tmp/nginx_purge.log" )
end

------------------------------------------------------ purge matching entries --
function purge_multi( safe_uri )
  -- escape special characters for grep
  local cache_key_re = string.gsub( cmp_cache_key, "([%.%[%]])", "\\%1" )
  local cache_key_re = string_replace( cache_key_re, cmp_uri, safe_uri..".*" )

  --os.execute( "grep -Raslm1 '^KEY: "..cache_key_re.."' "..cmp_cache_path.." | xargs -r rm -f" )
  os.execute( "grep -Raslm1 '^KEY: "..cache_key_re.."' "..cmp_cache_path.." >> /tmp/nginx_purge.log 2>&1" )
end

-------------------------------------------------------- purge specific entry --
function purge_one()
  local cache_key_md5 = md5.sumhexa( cmp_cache_key )
  -- os.execute( "find '"..cmp_cache_path.."' -name '"..cache_key_md5.."' -type f -exec rm {} +" )
  os.execute( "find '"..cmp_cache_path.."' -name '"..cache_key_md5.."' -type f >> /tmp/nginx_purge.log 2>&1" )
end

--------------------------------------------------------------------------------
------------------------------------- main -------------------------------------
--------------------------------------------------------------------------------
--

if ngx.var.request_uri == '/*' then
  purge_all()
else
  ------ FIXES
  -- remove tailing slash from cmp_cache_strip
  cmp_cache_strip = string.gsub( cmp_cache_strip, '/$', '' )
  -- url to be purged
  local cmp_uri = string.gsub( ngx.var.request_uri, "^"..cmp_cache_strip, "" )
  -- change the cache key to use the right url
  cmp_cache_key = string_replace( cmp_cache_key, ngx.var.request_uri, cmp_uri )

  -- check if last character of the request_uri is a *
  if string.find( string.reverse( cmp_uri ), '*', 1, 1 ) then
    -- uri is request_uri without the trailing *
    local uri = string.gsub( cmp_uri, '%*$', '' )
    if validate( uri ) then
      purge_multi( uri )
    else
      ngx.exit( ngx.HTTP_BAD_REQUEST )
    end
  else
    purge_one()
  end
end

ngx.exit( ngx.HTTP_NO_CONTENT ) -- Status code if everything works
