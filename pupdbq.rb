#!/usr/bin/env ruby

# Simple script to query the REST service on puppetdb
# Daniel Wittenberg <dwittenberg2008@gmail.com>

require 'rubygems'
require 'optparse'
require 'json'
require 'rest-client'
require 'pp'
require 'cgi'

$DEBUG="false"
$DEBUGLOG=""

def debug(msg)
  if($DEBUG == "true")
    if($DEBUGLOG != "") 
      File.open("#{$DEBUGLOG}",'a') {|f| f.puts("DEBUG: #{msg}")}
    else
      puts("DEBUG: #{msg}")
    end
  end 
end

def validate_input(opts)
  if(! opts[:hostname])
     opts[:hostname]="localhost"
  end
  if(! opts[:node])
     opts[:node]=`facter fqdn`
  end
end

def do_command(opts)
   case opts[:action]
      when "deactivate"
         command="deactivate node"
      else
	 puts "I don't know how to do that Dave"
   end
   
   url="http://#{opts[:hostname]}:8080/commands"
   debug("url: #{url}")
   msg=CGI::escape('{ "command": "#{command}", "payload": "\"#{opts[:node]}\"", "version": 1 }')
   msg="payload=#{msg}"
   debug("sending payload: #{msg}")
   result = RestClient.post url, "#{msg}", :content_type => 'application/x-www-form-urlencoded', :accept => 'application/json'
   debug("response code: #{result.code}")
   j = JSON.parse(result)
   j.sort.each do|k,l|
      if(l.nil?)
         puts "#{k}"
      else
         puts "#{k} = #{l}"
         l.sort.each do|m,n|
            puts "#{m} = #{n}" if(! n.nil?)
         end
      end
   end
   if($DEBUG == "true")
      pp j
   end
  
end

def do_query(opts)
   case opts[:action]
      when "all_active_nodes"
	 query=CGI::escape('["=",["node","active"],true]')
         query="query=#{query}"
         url="http://#{opts[:hostname]}:8080/nodes?#{query}"
      when "all_deactivated_nodes"
	 query=CGI::escape('["=",["node","active"],false]')
         query="query=#{query}"
         url="http://#{opts[:hostname]}:8080/nodes?#{query}"
      when "nodes"
         url="http://#{opts[:hostname]}:8080/#{opts[:action]}"
      when "facts"
         url="http://#{opts[:hostname]}:8080/#{opts[:action]}/#{opts[:node]}"
      when "resources"
	 puts "You can't handle the resources!"
         exit
         #url="http://#{opts[:hostname]}:8080/#{opts[:action]}/query"
      when "status"
         url="http://#{opts[:hostname]}:8080/#{opts[:action]}/nodes/#{opts[:node]}"
      when "metrics"
         url="http://#{opts[:hostname]}:8080/#{opts[:action]}/mbeans"
      else
	 puts "No soup for you!"
         exit
    end  

   debug("url: #{url}")
   result = RestClient.get url, { :accept => 'application/json' } 
   debug("response code: #{result.code}")
   j = JSON.parse(result)
   j.sort.each do|k,l|
      if(l.nil?)
         puts "#{k}"
      else
         puts "#{k} = #{l}"
         l.sort.each do|m,n|
            puts "#{m} = #{n}" if(! n.nil?)
         end
      end
   end
   if($DEBUG == "true")
      pp j
   end
end


def print_usage()
  puts "
Simple command-line interface to puppetDB API

   -h, --help                     Show this help message.
  
   -d, --debug                    Turn on debug mode

   -a  --action                   What action: 
                                  all_active nodes - list all active nodes
                                  all_deactivated_nodes - list all deactivated nodes
                                  nodes - list all nodes
                                  facts - show facts, -n node required
                                  resources - not implemented
                                  status - show status of a node, -n node required
                                  deactivate - deactivate a node, -n node required
   
   -H  --hostname                 Which puppetmaster to query: default=localhost

   -n  --node                     Which node to perform action on:  default=fqdn 
  
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

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: $0 [options]"
  
  opts.on('-d','--debug','Debugging mode on') do
      options[:debug] = true
      $DEBUG="true"
  end
  opts.on('-h','--help','Display help') do
    print_usage()
    exit
  end
  opts.on('-a','--action action','What action, all_active_nodes, nodes, facts, resources, status') do|action|
      options[:action] = action
  end
  opts.on('-H','--hostname hostname','What host to query - default: localhost') do|hostname|
      options[:hostname] = hostname
  end 
  opts.on('-n','--node nodename','Node name to perform action on - default: current fqdn') do|nodename|
      options[:node] = nodename
  end
end 

optparse.parse!

# Do some sanity checking on our inpurts
validate_input(options)

# If debug mode let's print our options so we confirm what our input was
options.each do |o,v|
  debug("#{o}=#{v}")
end

case options[:action]
when "nodes"
   puts "Query nodes"
   do_query(options)
when "facts"
   puts "Query facts"
   do_query(options)
when "resources"
   puts "Query resources"
   do_query(options)
when "status"
   puts "Query status for #{options[:node]}"
   do_query(options)
when "metrics"
   puts "Query metrics"
   do_query(options)
when "deactivate"
   puts "Deactivate node #{options[:node]}"
   do_command(options)
when "all_active_nodes"
   puts "All active nodes"
   do_query(options)
when "all_deactivated_nodes"
   puts "All deactivated nodes"
   do_query(options)
else
   puts "Don't know whow to process that action"
end



