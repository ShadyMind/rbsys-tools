#/usr/bin/ruby
require 'fileutils'

usr = "/usr/local"
opt = "/opt/local"

targets = [
    "#{usr}/bin/node",
    "#{usr}/bin/npm",
    "#{usr}/bin/node-debug",
    "#{usr}/bin/node-gyp",
    "#{usr}/lib/node",
    "#{usr}/lib/node_modules",
    "#{usr}/lib/dtrace/node.d",
    "#{usr}/include/node_modules",
    "#{usr}/include/node",
    Dir.glob("#{usr}/share/man/man1/node*"),
    Dir.glob("#{usr}/share/man/man1/npm*"),
    "#{usr}/share/doc/node",
    "#{usr}/share/systemtap/tapset/node.stp",
    "#{opt}/bin/node",
    "#{opt}/lib/node_modules",
    "#{opt}/include/node",
    "#{Dir.home}/.npmrc",
    "#{Dir.home}/.npm/",
    "#{Dir.home}/.node-gyp",
    "#{Dir.home}/.node_repl_history"
].flatten!

path_entity_name = ""

targets.each do |path|
    unless File.exists? path
        puts "\"#{path}\" does not exists"
        next
    end

    if File.directory? path
        FileUtils.rm_rf path
        path_entity_name = "Directory"
    end

    File.delete path
    path_entity_name = "File"

    puts "#{path_entity_name} \"#{path}\" removed"
end