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

### Example 1: Mimic the commercial [cache_purge](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_purge)

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

### Example 2: Use a custom location with a authentication token from a cookie

Add a map like this, for example in `/etc/nginx/conf.d/cache_purge.conf`

```
map $cookie_purge_token $purge_cache {
  default 0;
  b04f01fc92094bcc43d1cb78adc7836e 1;
}
```

Then add a location like this

```
location /cache/purge {
  set $cmp_run_if $purge_cache;
  set $cmp_cache_key $scheme$host$uri$is_args$args;
  set $cmp_cache_path "/var/www/cache/";
  set $cmp_cache_strip "/cache/purge/";
  content_by_lua_file /etc/nginx/lua/cache_multipurge.lua;
}
```

And done. After this:

* Request `GET /cache/purge/path/to/images/myimage.png` to purge that image.
* Request `GET /cache/purge/images/my*` to purge all images that start with *my* in that path.
* Request `GET /cache/purge/*` to purge all the cache.


## Optional keyfinder helper setup

If your cache consists of a large number of files, scanning it with `grep` can become quite slow. 
To gain better performance, you can use the included keyfinder helper. You’ll have to build it yourself, however.
### Requirements
You will need `gcc`, `libc` headers and `make`. On Debian/Ubuntu type (`libc` is included with `gcc`):
```
apt install gcc make
```
### Installation
Build the binary with 
```
make
```
and then install as root with 
```
make install
```
By default the `nginx_cache_keyfinder` binary is installed in `/usr/local/bin`. If you want a different location, you can copy it manually instead. 
### Configuration
Enable the keyfinder in your purge location config: 
```
set $cmp_cache_keyfinder 1;
```
If you choose to put the binary in a different location, you can adjust its path with
```
set $cmp_cache_keyfinder_path <path to binary>;
``` 
