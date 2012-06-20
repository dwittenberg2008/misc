#!/usr/bin/env ruby

##########################################################################
# Description : Take input from svn post-commit hook and create XML Feed
# Contact     : Daniel Wittenberg <dwittenberg2008@gmail.com>
# Inspired by : http://www.friday.com/bbum/2006/08/17/howto-adding-an-rss-feed-to-a-subversion-server/
# Based on    : http://svn.apache.org/repos/asf/subversion/trunk/tools/hook-scripts/svn2feed.py
##########################################################################

require 'rubygems'
require 'atom'
require 'optparse'
require 'pp'

$DEBUG="false"
$DEBUGLOG=""

# Need to make this conditional based on if you want ldap or not
#require 'ldap'

# TODO
# Fix ldap author lookups to use built-in ruby/ldap routines not shell out

  
##########################################################################
def debug(msg)
  if($DEBUG == "true")
    if($DEBUGLOG != "") 
      File.open("#{$DEBUGLOG}",'a') {|f| f.puts("DEBUG: #{msg}")}
    else
      puts("DEBUG: #{msg}")
    end
  end 
end

# Validate the input we get to make sure it's valid and sane
def validate_input(opts)
  # Do something
  #if(! opts[:svnpath]) 
  #  opts[:svnpath]=""
  #end
  
  if(! opts[:exporturl])
     opts[:exporturl]="http://localhost/svn/"
  end
  
  if(opts[:format] != "atom")
    opts[:format]="atom"
    puts "Format MUST be atom right now, so sorry"
  end
  
  if(! opts[:maxitems])
    opts[:maxitems]=25
  end
  
  if(! "#{opts[:itemurl]}".start_with?("http://","https://","file://"))
    puts "--item-url #{opts[:itemurl]} is not a valid URL"
    exit
  end
  
  if(! "#{opts[:feedurl]}".start_with?("http://","https://","file://"))
    puts "--feed-url #{opts[:feedurl]} is not a valid URL"
    exit
  end
  
  if(! opts[:revision])
    puts "--revision is required!"
    exit
  end
   
  if(! opts[:repo])
      puts "--repo is required!"
      exit
  end
    
  if(! opts[:feedfile])
    opts[:feedfile]="./output.xml"
  end
  
  if(! opts[:feedauthor])
      opts[:feedauthor]="Subversion/svn2feed.rb"
  end
    
  if(! opts[:ldapobjectclass])
      opts[:ldapobjectclass]="uid"
  end
  
  return
end

def ldapfindauthor(opts,author)
  debug("Looking for #{author} in ldap")

  # Need to do some lookups here
  if(! $authors[:"#{author}"])
     cmd=%x(ldapsearch -x -h #{opts[:ldapserver]} -b #{opts[:ldapbase]} #{opts[:ldapobjectclass]}=#{author} cn |grep ^cn: |awk -F: '{print $2}')
     cmd.gsub!(/^\s+/,"")
     cmd.gsub!(/\n$/,"")
     debug("Looking for author #{author} and found [#{cmd}]")
     if(cmd.empty?)
	cmd=author
     end
     $authors[:"#{author}"]=cmd
  else
     debug("Found #{author} of #{cmd} in cache")
     cmd=$authors[:"#{author}"]
  end

  return cmd
end

def process_changes(myvals,myopts)
  my_return = ""
  myvals[:changes].each do|chng|
     chng.gsub!(/\n$/,"")
     chng.gsub!(/^U\s+/,"")
     chng.gsub!(/^A\s+/,"")
     chng.gsub!(/^D\s+/,"")
     if(chng =~ /\.pp$/ && (myopts[:checkpuppetvalidate] || myopts[:checkpuppetlint]))
        debug("Checking puppet file: [#{chng}]")
        msg=validate_puppet_files(myopts,chng)
        msg="" if(msg == "\n")
     end
     my_return="#{my_return}#{msg}"
     debug("Message: [#{msg}]")
  end
  debug("Returning message: #{my_return}")
  
  return "#{my_return}" 
end

# We'll be using svnlook to get information about the commit and revision
def get_values(opts)
   vals = {}
   if(opts[:feedtitle]) 
     vals[:feedtitle] = "#{opts[:feedtitle]}"
   end
   vals[:feedtitle]="SVN Commits" if(! opts[:feedtitle])
   vals[:fid]="urn:uuid:60a76c80-d399-11d9-b93C-0003939e0af6-#{opts[:revision]}"
   vals[:itemtitle]="Commit Title"
   vals[:iid]="urn:uuid:1225c695-cfb8-4ebb-aaaa-80da344efa6a-#{opts[:revision]}"
   vals[:fupdated]=Time.now
   vals[:iupdated]="0000-00-00T00:00:00Z"
   vals[:author]="author"  
   
   # This is multi-line output, we only care about the first two lines though 
   cmd=%x(#{opts[:svnpath]}/svnlook info -r #{opts[:revision]} #{opts[:repo]} ) 
   info_lines=cmd.split(/\n/)

   # First line gets the author
   if(info_lines[0]) 
     vals[:author] = "#{info_lines[0]}"
     if(opts[:ldapauthor])
       found_author=ldapfindauthor(opts,"#{info_lines[0]}")
       if(found_author) 
         vals[:author]="#{found_author}"
       end
     end
   end
   
   # Second line gets the date of the update
   if(info_lines[1])
     vals[:iupdated] = "#{info_lines[1]}"
   end

   # Get the commit log entry for this revision
   vals[:summary]=%x(#{opts[:svnpath]}/svnlook log -r #{opts[:revision]} #{opts[:repo]})
   "#{vals[:summary]}".gsub!(/\n$/,"")

   # Make part of the title of the article the commit message
   if(vals[:summary])
      vals[:itemtitle]="Rev #{opts[:revision]} : #{vals[:summary]}" 
      pad=""
      if(vals[:itemtitle].length > 60) 
          pad="..."
      end
   end
   vals[:itemtitle].gsub!(/\n/,"")
   vals[:itemtitle]=vals[:itemtitle].slice(0..60)
   vals[:itemtitle]="#{vals[:itemtitle]}#{pad}"

   debug("get_vals: itemtitle: #{vals[:itemtitle]}")
   
   # We need to replace newline with html BR and then a newline so it shows up correctly
   # in the feed reader since they expect HTML usually 
   vals[:summary].gsub!(/\n/,"<br/>\n")
     
   # Get the details of actually changed
   vals[:changes]=%x(#{opts[:svnpath]}/svnlook changed -r #{opts[:revision]} #{opts[:repo]})
   opts[:endrev]=0 if(! opts[:endrev]) 
   if("#{opts[:revision]}" == "#{opts[:endrev]}")
      my_results=process_changes(vals,opts)
      if(my_results != "")
         debug("Check_results: #{my_results}")
         vals[:check_results]="Puppet manifest validation results:#{my_results}"
         vals[:check_results].gsub!(/\n/,"<br/>\n")
      end
   end
   vals[:changes].gsub!(/\n/,"<br/>\n")
   if(opts[:colorize]) 
      vals[:changes].gsub!(/^U\s/,"<b><font color='orange'>Updated:</font></b> ")
      vals[:changes].gsub!(/^A\s/,"<b><font color='green'>Added:</font></b> ")
      vals[:changes].gsub!(/^D\s/,"<b><font color='red'>Deleted:</font></b> ")
   else 
     vals[:changes].gsub!(/^U\s/,"Updated: ")
     vals[:changes].gsub!(/^A\s/,"Added: ")
     vals[:changes].gsub!(/^D\s/,"Deleted: ")
   end
   
   return vals
end

# Use ratom to build the actual feed
# We might be building 2 feeds, one for "everything" and one for the
# particular subdirectory that's being worked on
def build_feed(opts)
  vals=get_values(opts)
  
  # Setup the main feed information
  feed = Atom::Feed.new do |f|
    f.title = "#{vals[:feedtitle]}"
    f.links << Atom::Link.new(:href => "#{opts[:feedurl]}")
    f.updated = Time.parse("#{vals[:fupdated]}")
    f.authors << Atom::Person.new(:name => "#{opts[:feedauthor]}")
    f.id = "#{vals[:fid]}"
    
    # Loop through the last maxitems number and get those revisions
    newrev=opts[:revision].to_i - opts[:maxitems].to_i
    orev=opts[:revision].to_i
    opts[:endrev]=opts[:revision]
     
    # Of course if we have < maxentries then just go to revision 1
    if(newrev < 0) 
      newrev=1
      opts[:startrev]=newrev
    end
      
    while newrev <= orev
      opts[:revision]=newrev
      debug("Getting revision #{opts[:revision]}")
      values=get_values(opts)
      newrev=newrev+1
      
      f.entries << Atom::Entry.new do |e|
        e.title = "#{values[:itemtitle]}"
        e.summary = "#{values[:summary]}"
        e.links << Atom::Link.new(:href => "#{opts[:itemurl]}#{opts[:revision]}")
        e.id = "#{values[:iid]}"
        e.updated = Time.parse("#{values[:iupdated]}")
        e.authors << Atom::Person.new(:name => "#{values[:author]}")
        if(opts[:colorize])
           e.content = "<font color='blue'>Summary<br/>\nChanged files<br/>\n#{values[:summary]}</font><br/>\n#{values[:changes]}<br/>\n#{values[:check_results]}"
        else
           e.content = "Summary<br/>\n#{values[:summary]}<br/>\nChanged files<br/>\n#{values[:changes]}<br/>\n#{values[:check_results]}"
        end
        
      end
    end
  end
  
  return feed
end

def export_feed(feed,opts)
  debug("Writing feed file: #{opts[:feedfile]}")
  File.open("#{opts[:feedfile]}",'w') {|f| f.puts feed.to_xml }
  File.chmod(0644, "#{opts[:feedfile]}")   
  return    
end

def validate_puppet_files(opts,file)
  dir="/tmp/.svn_validate." + $$.to_s + "/"
  if(! File.exist?(dir))
     Dir.mkdir(dir,0700)
  end
  Dir.chdir(dir)
  url="#{opts[:exporturl]}/#{file}"
  svn_export=%x(pwd; #{opts[:svnpath]}/svn export #{url} 2>&1)
  debug("svn_export: #{svn_export}")
  filename=%x(basename "#{file}")
  filename.gsub!(/\n$/,"")
  filename=dir + filename
  debug("Testing file: #{filename}")

  # Make a report of the results 
  output="\n-- #{filename} --\n"
  
  # Now we should check the syntax
  if(opts[:checkpuppetvalidate])
    debug("puppet parser validate --color=false #{filename} 2>/dev/null")
    msg=%x(puppet parser validate --color=false #{filename} 2>/dev/null | grep -ve "err: Try 'puppet help parser validate' for usage")
    msg.gsub!(/\n$/,"")
    debug("puppet parser validate:\n[#{msg}]\n")
    if(msg.empty?)
       msg="** Basic syntax check passed **\n"
    else
       msg="** Syntax ERRORS **\n" + msg + "<br/>\n"
    end
    output=output + msg
  end

  if(opts[:checkpuppetlint])
    # Check the manifest against the style-guide
    # exclude 80chars for now since the HEADURL tag in SVN al
    debug("puppet-lint --no-80chars-check #{filename}")
    msg=%x(puppet-lint --no-80chars-check "#{filename}" 2>/dev/null)
    msg.gsub!(/\n$/,"")
    debug("puppet-lint :\n[#{msg}]")
    if(msg.empty?)
       msg="** Style guide check passed **\n"
    else
       msg="\n** Recommended style changes **\n" + msg
    end
    output=output + msg
  end

  output=output + "\n-- --\n"
  debug("output: #{output}")

  # Cleanup the temporary checkout directory
  %x(rm -f #{dir}/*)
  %x(rmdir #{dir})
  

  return output
end

def print_usage()
  puts "
   -h, --help                     Show this help message.
  
   -d, --debug                    Turn on debug mode
  
       --debug-log=FILE           File to output debug messages to (default=none)
  
   -F, --format=FORMAT            Required option.  FORMAT must be one of:
                                   'rss'  (RSS 2.0)
                                   'atom' (Atom 1.0)
                                  to select the appropriate feed format.
  
   -f, --feed-file=PATH           Store the feed in the file located at PATH, which will
                                  be created if it does not exist, or overwritten if it
                                  does.  If not provided, the script will store the feed
                                  in the current working directory, in a file named
                                  REPOS_NAME.rss or REPOS_NAME.atom (where REPOS_NAME is
                                  the basename of the REPOS_PATH command-line argument,
                                  and the file extension depends on the selected
                                  format).
  
   -r, --revision=X               Subversion revision to generate info for.
  
   -R  --repo=REPO                The name of the repo to check
  
   -m, --max-items=N              Keep only N items in the feed file.  By default,
                                  20 items are kept.
  
   -u, --item-url=URL             Use URL as the basis for generating feed item links.
                                  This value is appended with '?rev=REV_NUMBER' to form
                                  the actual item links.
  
   -U, --feed-url=URL             Use URL as the global link associated with the feed.
  
   -T  --feed-title=TITLE         Manually give your feed a title
  
   -A  --feed-author=NAME         Who should the author of the feed be displayed as
  
   -P, --svn-path=DIR             Look in DIR for the svn binaries.  If not provided,
                                  svn and svnlook must be on the PATH.
  
   -x, --export-url=PATH          Base URL used by the svn export command
                                  Default: http://localhost/svn/
  
       --check-puppet-syntax      Use the puppet parser validate <file> for any .pp file
  
       --check-puppet-lint        Use puppet-lint to check any .pp file
  
       --colorize                 Use HTML color fonts in the output to make more readable
                                  * Note that some news readers don't recognize all HTML tags like color
  
       --ldap-author              Lookup the author name in ldap
  
       --ldap-server              Server to lookup author
  
       --ldap-base                Base DN to find the author
  
       --ldap-objectclass         What objectclass to search for the author (default=uid)
"
   exit
end

#######################################
#    __  __          _____ _   _ 
#   |  \/  |   /\   |_   _| \ | |
#   | \  / |  /  \    | | |  \| |
#   | |\/| | / /\ \   | | | . ` |
#   | |  | |/ ____ \ _| |_| |\  |
#   |_|  |_/_/    \_\_____|_| \_|
#
#######################################

$authors = {}
options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: $0 [options]"
  
  opts.on('-d','--debug','Debugging mode on') do
      options[:debug] = true
      $DEBUG="true"
  end
  opts.on('--debug-log dbglog','Debugging mode on') do|dbglog|
      options[:debuglog] = dbglog
      $DEBUGLOG="#{options[:debuglog]}"
  end
  opts.on('--check-puppet-validate','Validate puppet manifest syntax') do
      options[:checkpuppetvalidate] = true
  end
  opts.on('--check-puppet-lint','Check style of puppet manifest') do
        options[:checkpuppetlint] = true
  end
  opts.on('--ldap-author','Lookup author in LDAP') do
      options[:ldapauthor] = true
  end
  opts.on('--ldap-server ldaps','LDAP server') do|ldaps|
        options[:ldapserver] = ldaps
  end
  opts.on('--ldap-base ldaob','LDAP Base DN') do|ldapb|
        options[:ldapbase] = ldapb
  end  
  opts.on('--ldap-objectclass ldapo','LDAP objectclass') do|ldapo|
        options[:ldapobjectclass] = ldapo
  end   
  opts.on('-F','--format frmt','atom or rss') do|frmt|
    options[:format] = frmt
  end
  opts.on('-f','--feed-file fd','Feed file') do|fd|
    options[:feedfile] = fd
  end
  opts.on('-T','--feed-title ft','Feed title') do|ft|
      options[:feedtitle] = ft
  end
  opts.on('-A','--feed-author fa','Feed author') do|fa|
        options[:feedauthor] = fa
  end
  opts.on('-r','--revision rev','SVN Revision') do|rev|
    options[:revision] = rev
  end
  opts.on('R','--repo repo','SVN Repo') do|rep|
      options[:repo] = rep
  end
  opts.on('-m','--max-items max','Max number of items to return') do|max|
    options[:maxitems] = max
  end
  opts.on('-u','--item-url url','Item URL') do|url|
    options[:itemurl] = url
  end
  opts.on('-U','--feed-url furl','Feed URL') do|furl|
    options[:feedurl] = furl
  end
  opts.on('-P','--svn-path path','Path to the svn commands') do|path|
    options[:svnpath] = path
  end
  opts.on('-x','--export-url xurl','Base svn export path') do|xurl|
    options[:exporturl] = xurl
  end
  opts.on('-h','--help','Display help') do
    print_usage()
    exit
  end
end

optparse.parse!

# If debug mode let's print our options so we confirm what our input was

options.each do |o,v|
  debug("#{o}=#{v}")
end


# Do some sanity checking on our inpurts
validate_input(options)

# Build the feed information, we'll chose to export it next
thefeed=build_feed(options)

# Ok we should have all the data now write it out to a file
export_feed(thefeed,options)
             

# Should be all done now
