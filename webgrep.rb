#Charles Teese
#Principles of Programming Languages
#HW 3
#ruby 1.9.3p374 (2013-01-15 revision 38858) [x86_64-darwin12.2.1]

require 'mechanize'
require 'set'
require 'thread'

class WebGrep 	#finds uri's that contian a given regualr expression starting at a given page and traversing out through its links. 
	def initialize(regexpress = ARGV[0], pageurl = ARGV[1], depth = ARGV[2])
		@mech = Mechanize.new 	#creates new instance of mechanize class
		@string = regexpress	#saves the string to be printed out for debuggin
	    @regexpress = /#{regexpress}/	#converts the string into a regular expression 
	    @depth = depth.to_i - 1 	#sets the depth of the Link tree to the parameter minus one becasue depth 0 should not be counted
	    @link_tree = LinkTree.new(@mech.get(pageurl), @depth, @mech)	#creates the link tree containing only the root node
	end

	def run 	#generates the rest of the link tree to the specified depth, then searches all the pages in the tree for the regular expression
	    # puts "Generating Link Tree"
	    @link_tree.generateTree
	    # puts "#{@string} can be found on the following pages:"
	    @link_tree.bfs {|node| puts node.uri if checkString(node)}
	end

  private
	def checkString(node)	#converts the page text of node to UTF-8 and then checks if it contians the regualr expression
		valid_text = node.pageText.encode('UTF-16', :undef => :replace, :invalid => :replace)
		valid_text.encode!('UTF-8')
		valid_text.match(@regexpress) != nil
	end

end

class LinkTree #a Tree of pages and the pages they link to 
	def initialize(root, depth, mech)	#creates a new LinkTree containing only the root node
		@mech
		@root = LinkTreeNode.new(root, mech)
		@depth = depth
	end

	def generateTree 	#fills in the rest of the LinkTree to @depth
		@visited = {@root.uri => @root}
		linkToDepth(@depth, @root)
		return "Link Tree Successfully Created"
	end

	def bfs(&block) #breadth first search:goes to each node in the tree and calls &block on each unique node 
		visited = Set.new
		queue = Queue.new
		queue << @root
		@root.enqueued=true
		block.call(@root)
		while !queue.empty?
			t = queue.pop
			t.link_list.each do |w|
				if !w.enqueued
					if !visited.include?(w.uri)
						block.call(w)
						visited.add(w.uri)
					end
					queue << w
					w.enqueued=true
				end
			end
		end
	end


  private
	def linkToDepth(depth, node)	#recusivly fills out the tree to given depth 
		return nil if depth == 0
		node.parseLinks(@visited)
		node.link_list.each do |i|
			linkToDepth(depth-1, i)
		end
	end
end

class LinkTreeNode 	#a node that has a list of all it's children 
	attr_accessor :enqueued
	attr_reader :link_list


	def initialize(page, mech) #creates a new LinkTreeNode with an empty link list
		@mech = mech
		@page = page
		@link_list = []
		@enqueued = false
	end

	def pageText	#returns a string contianing the content of the page. If it's not a web page it returns an empty string.
		if @page.class == Mechanize::Page
			@page.parser.text
		else
			""
		end
	end

	def uri 	#returns the uri of the page
		@page.uri.to_s
	end

	def parseLinks(visited) 	#creates LinkTreeNodes from the list of links on this node's page
		if @page.class == Mechanize::Page && @link_list.empty? 	#makes sure the link is to a web page and not a file
			@page.links.each do |i| 	#iterates through the links on the current node's page
				new_link = parseURI(i.uri.to_s)
				new_node = nil
				if !visited.key?(new_link)
					begin
						new_node = LinkTreeNode.new(@mech.click(i), @mech)
					rescue Mechanize::ResponseCodeError => e 	#for pages that have popups requiring a response this gets the page from the error it throws
						new_node = LinkTreeNode.new(e.page, @mech)
					rescue Mechanize::UnsupportedSchemeError, URI::InvalidURIError, SocketError, Net::HTTP::Persistent::Error  => e 	#pages with other errors are ignored 
						# puts e
					end
					if !new_node.nil?
						visited[new_node.uri] = new_node
						@link_list.push(new_node)
					end
				else
					@link_list.push(visited[new_link])
				end
			end
		end
	end

  private
	def parseURI(link) #makes sure that the link is a full http:// link
		if link.start_with?("http://", "https://")#leavs http:// links alone
			link
		else
			page = uri
			if link != '/'
				if link.start_with?('#') #appends # links to the end of the current URI
					link = page << link
				else
					if(page.end_with?('/'))
						page.chop!
					else
						while !page.end_with?('/') #removes tail char of URI until you reach the first /
							page.chop!
						end
					end
					page.chop! if page.end_with?('/')		#removes / on page
					link.slice!(0) if link.start_with?('/')	#removes / on link 
					link = page << '/' << link 		#appends a / to page followed by the link
				end
			else	#returns links that are / as the uri of the current page
				while !page.end_with?('/')
					page.chop!
				end
				link = page
			end
			link.rstrip
		end
	end 
end

grep = WebGrep.new
grep.run
