all: sync-www sync-picasa sync-blog 

sync-picasa:
	org2tumblr picasa

sync-blog:
	org2tumblr --www=http://www.yourstaticsite.com tumblr blog.org

sync-www:
	# this is an idea, do what is best for your situation :)
	# rsync --exclude=.DS_Store -avz --delete www www.yourstaticsite.com:somepath/

