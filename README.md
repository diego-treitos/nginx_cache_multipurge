# Nginx Cache Multipurge (lua)

## Description

Handle **cache purges** in a versatile and easy way. This *lua module* will allow you to request the removal from cache of **one or multiple** urls using a wild card `*` at the end.


## Requirements

 * Nginx Lua Module
 * MD5 Lua Library
 
 If you are on Debian/Ubuntu
 
 ```
 apt install libnginx-mod-http-lua lua-md5
 ```
 
## Installation
 
* Install the above requirements
* Copy the `cache_multipurge.lua` file to a path readable by the user that runs *nginx*. (i.e. `/etc/nginx/lua`)


## Configuration

### Available Configuration Variables

* `$cmp_run_if`: (**mandatory**) In case it is not empty and not equal to `0` the cache purge will be run. The default is an empty string so you **have to** add this parameter for the cache purge to work.
* `$cmp_cache_key`: (**mandatory**) Value of the key used in your cache. This should be the same than the value provided to `proxy_cache_key`, `fastcgi_cache_key`, etc.
* `$cmp_cache_path`: (**mandatory**) Path to where your cache files are stored in your filesystem. This value should match the one provided to `proxy_cache_path`, `fastcgi_cache_path`, etc.
* `$cmp_cache_strip`: Path to strip from the beginin of a URL before the URL is cleared from cache. This is useful if you call the *nginx_cache_multipurge* from a location different than `/`. For example, if you are using `/cache/purge` as your location to purge the cache, your `$cmp_cache_strip` should be `/cache/purge`, this way, when requesting `/cache/purge/my/file.png` the URL to purge will be `/my/file.png`.

### Mimic the commercial [cache_purge](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_purge)

Add this map somewhere (i.e. `/etc/nginx/conf.d/method_map.conf`)

```
map $request_method $cmp_run_if {
    default 0;
    PURGE 1;
}
```

Then, in a location

```
location / {
  proxy_pass http://backend;
  proxy_cache my-awesome-cache;
  proxy_cache_key $scheme$host$uri$is_args$args;
  
  # NOTE: We already defined $cmp_run_if in the map
  set $cmp_cache_key $scheme$host$uri$is_args$args;
  set $cmp_cache_path "/var/www/cache";
  content_by_lua_file /etc/nginx/lua/cache_multipurge.lua;
}
```

And done. After this:

* Request `PURGE /path/to/images/myimage.png` to purge that image.
* Request `PURGE /path/to/images/my*` to purge all images that start with *my* in that path.
* Request `PURGE /*` to purge all the cache.




The *requested URL* is used 
