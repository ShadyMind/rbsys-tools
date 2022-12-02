require 'rbconfig'
require 'json'
require 'net/https'
require 'rubygems/package'
require 'fileutils'

REGISTRY_NODE_URI = "https://registry.npmjs.com/node/"
DIST_NODE_URI = "https://nodejs.org/dist/"
RELEASE_NODE_URI = "https://nodejs.org/download/release/"

def fetch_get(uri)
  unless uri.is_a? URI
    uri = URI.parse uri
  end

  http = Net::HTTP.new uri.host, uri.port
  http.ssl_timeout = 5
  
  if uri.scheme.to_s.downcase == 'https'
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end

  request = Net::HTTP::Get.new uri
  response = http.request request

  return response
end

def sys_data()
  return {
    :arch => (
      case RUBY_PLATFORM
      when /x86_64/i
        :x64
      when /i[36]86/i
        :x32
      when /(aarch64(_be)?|armv8[bl])/i
        :arm64
      when /armv7l/i
        :arm7l
      when /ppc64le/i
        :ppc64le
      when /ppc64/i
        :ppc64l
      end
    ),
    :type => (
      case RUBY_PLATFORM
      when /mswin|msys|mingw|cygwin|bccwin|wince|emc/i
        :win
      when /darwin|mac os/i
        :darwin
      when /linux/i
        :linux
      when /solaris|bsd/i
        :unix
      else
        :unknown
      end
    )
  }
end

args = ARGV.reduce({ "version" => "latest" }) do |acc, arg| 
  entry = /\-\-([a-z0-9\-]+)(=([a-z0-9]+))?/.match(arg.downcase)
  acc[entry[1].to_s] = entry[3] || true
  acc
end

args['version'] = args['version'].gsub(/^v?(\d+)$/i, 'v\1-lts')

print "\nFecth available versions from \"#{REGISTRY_NODE_URI}\" ..."
print " Done!\n"
resp_repo = fetch_get(REGISTRY_NODE_URI)
repo_data = JSON.parse resp_repo.body

puts "Possible tags:"
repo_data['dist-tags'].keys.each do |key|
  puts "  – \"#{key}\""
end
node_version = repo_data['dist-tags'][args['version']]
print "Choosed version: \"#{args['version']}\" (v#{node_version})\n"

print "Fetch available binaries from \"#{DIST_NODE_URI}v#{node_version}\" ..."
resp_dist = fetch_get("#{DIST_NODE_URI}v#{node_version}/")
distros = resp_dist.body.scan /<a href="(.+?)">.+?<\/a>/im

print " Done!\n"

os_props = sys_data()
print "Looking for OS specific binaries with type \"#{os_props[:type]}\" and arch \"#{os_props[:arch]}\" ..."
sample = "node-v#{node_version}-#{os_props[:type]}-#{os_props[:arch]}.tar.gz"

package_name = (distros.detect{|d|d[0] == sample})[0]
package_uri = "#{DIST_NODE_URI}v#{node_version}/#{package_name}"

unless package_uri.is_a? String
  raise "Fail"
end

print " Found package \"#{package_name}\"!\n"

print "Download specific binaries from \"#{package_uri}\" ..."
resp_bin = fetch_get(package_uri)

FileUtils.mkdir_p './tmp'
archive_file = File.open "./tmp/node-#{node_version}.tar.gz", 'w'
archive_file.write resp_bin.body
archive_file.close

File.open archive_file.path, 'rb' do |file|
  Gem::Package::TarReader.new(Zlib::GzipReader.open(file)) do |tar|
    tar.each do |entry|
      if entry.file?
        FileUtils.mkdir_p(File.dirname("./tmp/#{entry.full_name}"))
        File.open("./tmp/#{entry.full_name}", "wb") do |f|
          f.write(entry.read)
        end
        File.chmod(entry.header.mode, "./tmp/#{entry.full_name}")
      end
    end
  end
end


print " Done!\n"

binaries_root = "./tmp/node-v#{node_version}-#{os_props[:type]}-#{os_props[:arch]}"

FileUtils.copy_entry("#{binaries_root}/bin/node", '/usr/local/bin/node')
FileUtils.chmod(0755, '/usr/local/bin/node')

FileUtils.copy_entry("#{binaries_root}/include/node/", '/usr/local/include/node/')
FileUtils.copy_entry("#{binaries_root}/lib/node_modules/", '/usr/local/lib/node_modules/')


if File.exists? '/usr/local/bin/npm'
  File.delete '/usr/local/bin/npm'
end

FileUtils.symlink('/usr/local/lib/node_modules/npm/bin/npm-cli.js', '/usr/local/bin/npm')
FileUtils.chmod(0755, '/usr/local/bin/npm')

if File.exists? '/usr/local/bin/npx'
  File.delete '/usr/local/bin/npx'
end

FileUtils.symlink('/usr/local/lib/node_modules/npm/bin/npx-cli.js', '/usr/local/bin/npx')
FileUtils.chmod(0755, '/usr/local/bin/npx')

if File.exists? '/usr/local/bin/corepack'
  File.delete '/usr/local/bin/corepack'
end

FileUtils.symlink('/usr/local/lib/node_modules/corepack/dist/corepack.js', '/usr/local/bin/corepack')
FileUtils.chmod(0755, '/usr/local/bin/corepack')
