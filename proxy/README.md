Xtend Overview
==============

### Basics:

First, forward your local ports 80 & 443 to 3000 and 3443 respectively
like this:

    ipfw add 100 fwd 127.0.0.1,3000 tcp from any to me 80
    ipfw add 101 fwd 127.0.0.1,3443 tcp from any to me 443

See this guide on making self-signed ssl certs always trust:

http://www.robpeck.com/2010/10/google-chrome-mac-os-x-and-self-signed-ssl-certificates/

Type this to start the proxy server:

    cake run

One can access a site via *.myapp.dev via the following heuristic:
A url like www.google.com becomes www-google-com.myapp.dev in our
system.

### app.coffee

Express server that has 2 routes:  '/x_t_n_d/:name' and '*'.  The first
route is used to serve up the client side js that contains all the
rewriters & parsers, the second is for the actual proxying.

The proxy serves up a response by piping it through ProxyStream from
node-request.  ProxyStream will be the candidate for dealing with
headers & cookies, it currently messes with html & js and does a
passthrough when the content is binary.

### browser.coffee

This is the entry point for modul8 for converting all client-side js
into a single file.  Here we will initialize parameters specific to the
browser client.

### dns_server.coffee

Primary used for development mode.  One should create a file called
'dev' inside of /etc/resolver/ that should contain the following:

    nameserver 127.0.0.1

This will allow the wildcard dns, *.myapp.dev, to resolve to localhost.

### guide.coffee

The JS rewrite rules are contained in here.  The idea is to use this in
the future as the central place for all html & js rewrite rules &
substitutions.  It should be a small file so that it's easy to
understand.

### html.coffee

Rewriter for html.  Currently very basic and doesn't handle corner cases
well.

### js.coffee

This is the Caja equivalence for rewriting js using a DSL.

### proxy_stream.coffee

This is used by app.coffee for filtering data from the remote machine.

### xtnd.coffee

This is where all the work needs to be done.  The JS rewriter would
convert code that depends on the functions in this file.  It contains
the url conversions & property modifications.  Lots of stuff to be added
here soon.

### files inside of client/

These are equivalent npm package files that are only served up by the
client, inside the browser.  They are packaged by the modul8 system.


