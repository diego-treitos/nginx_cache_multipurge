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
-- Value of the cache_key variable. i.e. $proxy_cache_key
local cmp_cache_key = ngx.var.cmp_cache_key
-- Path where the cache files are stored. i.e. /var/www/cache
local cmp_cache_path = ngx.var.cmp_cache_path
-- Initial segment of the URL to be stripped to get the URL to purge. i.e. /purge/dynamic
local cmp_cache_strip = ngx.var.cmp_cache_strip or ''

------ FIXES
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


--------------------------------------------------------------------------------
------------------------------ purge functions ---------------------------------
--------------------------------------------------------------------------------
--
----------------------------------------------------------- purge all entries --
function purge_all()
  os.execute( "rm -rd '"..cmp_cache_path.."/*'" )
end

------------------------------------------------------ purge matching entries --
function purge_multi( safe_uri )
  -- escape special characters for grep
  local cache_key_re = cmp_cache_key:gsub( "([%.%[%]])", "\\%1" )
  local cache_key_re = cache_key_re:gsub( cmp_uri:gsub("%p","%%%1"), safe_uri..".*" )

  os.execute( "grep -Raslm1 '^KEY: "..cache_key_re.."' "..cmp_cache_path.." | xargs -r rm -f" )
end

-------------------------------------------------------- purge specific entry --
function purge_one()
  local cache_key_md5 = md5.sumhexa( cmp_cache_key )
  os.execute( "find '"..cmp_cache_path.."' -name '"..cache_key_md5.."' -type f -exec rm {} +" )
end

--------------------------------------------------------------------------------
------------------------------------- main -------------------------------------
--------------------------------------------------------------------------------
--
-- check if last character of the request_uri is a *
if string.find( string.reverse( cmp_uri ), '*', 1, 1 ) then
  if cmp_uri == '/*' then
    purge_all()
  else
    -- uri is request_uri without the trailing *
    local uri = string.gsub( cmp_uri, '%*$', '' )
    if validate( uri ) then
      purge_multi( uri )
    else
      ngx.exit( ngx.HTTP_BAD_REQUEST )
    end
  end
else
    purge_one()
end

ngx.exit( ngx.HTTP_NO_CONTENT ) -- Status code if everything works
