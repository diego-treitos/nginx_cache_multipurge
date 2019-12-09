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
local cmp_cache_key = ngx.var.cmp_cache_key -- i.e. $proxy_cache_key
local cmp_cache_path = ngx.var.cmp_cache_path -- i.e. /var/www/cache


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


function purge_all()
  os.execute( "rm -rd '"..cmp_cache_path.."/*'" )
end

function purge_multi( safe_uri )
  -- escape special characters for grep
  local cache_key_re = string.gsub( cmp_cache_key, "([%.%[%]])", "\\%1" )
  local cache_key_re = string.gsub( cache_key_re, ngx.var.request_uri, safe_uri..".*" )

  os.execute( "grep -Raslm1 '^KEY: "..cache_key_re.."' "..cmp_cache_path.." | xargs -r rm -f" )
end

function purge_one( uri )
  local cache_key_md5 = md5.sumhexa( cmp_cache_key )
  os.execute( "find '"..cmp_cache_path.."' -name '"..cache_key_md5.."' -type f -exec rm {} +" )
end

--------------------------------------------------------------------------------
------------------------------------- main -------------------------------------
--------------------------------------------------------------------------------
--

if ngx.var.request_uri == '/*' then
  purge_all()
else
  -- check if last character of the request_uri is a *
  if string.find( string.reverse( ngx.var.request_uri ), '*', 1, 1 ) then
    -- uri is request_uri without the trailing *
    local uri = string.sub( ngx.var.request_uri, 1, string.len( ngx.var.request_uri ) - 1 )
    if validate( uri ) then
      purge_multi( uri )
    else
      ngx.exit( ngx.HTTP_BAD_REQUEST )
    end
  else
    purge_one( ngx.var.request_uri )
  end
end

ngx.exit( ngx.HTTP_NO_CONTENT ) -- Status code if everything works
