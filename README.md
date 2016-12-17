# mediawiki-developer-tools
Simple developer related tools for MediaWiki

Example Usage:

<code>
cd extensions
git-wmf pull
</code>

Example Usage:

<code>
cd extensions
git-all pull
</code>

Note:
At least when using Windows, it's best to set SSH connection keep-alive to avoid TCP connection spam in TIME_WAIT that can lead to exhaustion. E.g.:

<code>
Host gerrit.wikimedia.org
   ServerAliveInterval 60
</code>
