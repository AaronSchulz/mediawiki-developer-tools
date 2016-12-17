# mediawiki-developer-tools
Simple developer related tools for MediaWiki

The git-all.sh and git-wmf.sh scripts can pull/clone the master branch of all gerrit-hosted MediaWiki extensions into the current folder. The later only draws in those extensions listed at extension-list in the mediawiki-config repository used by Wikimedia. Usage is of the form <code>git-all pull</code> or <code>git-wmf pull</code>.

Note:
At least when using Windows, it's best to set SSH connection keep-alive to avoid TCP connection spam in TIME_WAIT that can lead to exhaustion. E.g.:

<code>
Host gerrit.wikimedia.org
   KeepAlive yes
   ServerAliveInterval 60
</code>
