require 'chef/knife'

class Chef
  class Knife
    class LibvirtStorageVolumeCreate < Knife
		deps do
			require 'libvirt'
		end
		banner "knife libvirt storage volume create (options)"
		option :size,
			:short => "-s SIZE",
			:long  => "--size SIZE",
			:description => "The size of the volume in GB",
			:proc => Proc.new { |s| Chef::Config[:knife][:size] = s },
			:default => "10"
		option :name,
			:short => "-n NAME",
			:long  => "--name NAME",
			:description => "The name of the volume with extension",
			:proc => Proc.new { |n| Chef::Config[:knife][:name] = n }
		option :type,
			:short	=> "-T TYPE",
			:long	=> "--type TPYE",
			:description	=> "Specify the type of storage to allocate for the new node",
			:proc => Proc.new { |t| Chef::Config[:knife][:type] = t }	
		
		option :pool,
			:short	=> "-P STORAGE_POOL",
			:long	=> "--pool STORAGE_POOL",
			:description => "Specify pool within which to create volume",
			:proc => Proc.new { |l| Chef::Config[:knife][:storage_pool] = l }

		def run
			puts "Allocating storage..."
			host = Chef::Config[:libvirt_uri]
			connection = Libvirt::open(host)
			storage_volume_xml = <<-EOF
				<volume>
					<name>#{Chef::Config[:knife][:name]}.img</name>
					<allocation>0</allocation>
					<capacity unit="G">#{Chef::Config[:knife][:size]}</capacity>
					<target>
						<path>#{Chef::Config[:libvirt_storage_path]}/#{Chef::Config[:knife][:name]}.img</path>
						<format type='#{Chef::Config[:knife][:type]}'/>
					</target>
				</volume>
			EOF
			
			pool_name = "#{Chef::Config[:knife][:storage_pool]}"
			pool = connection.lookup_storage_pool_by_name(pool_name)
			vol = pool.create_vol_xml(storage_volume_xml)
			pool.refresh
			puts "Created a #{Chef::Config[:knife][:type]} volume of size #{Chef::Config[:knife][:size]} GB located at #{Chef::Config[:libvirt_storage_path]}/#{Chef::Config[:knife][:name]}.img on the hypervisor"
			#storage_pool.list_volumes.each do |volume|
            		#vols = storage_pool.lookup_volume_by_name(volume)
            		#puts "#{volume} #{to_mb(vols.info.allocation)} MB/#{to_mb(vols.info.capacity)} MB"
          		#end
          		puts "-"*80
		end
	end
	class LibvirtStoragePoolList < Knife
      deps do
        require 'libvirt'
      end
      banner "knife libvirt storage pool list (options)"

      def run
	puts "Listing storage pools..."
        uri = Chef::Config[:libvirt_uri]
        connection = Libvirt::open(uri)
        puts connection.list_storage_pools
      end
    end
        
    class LibvirtStoragePoolShow < Knife
      deps do
        require 'chef/knife/bootstrap'
        Chef::Knife::Bootstrap.load_deps
        require 'libvirt'
        require 'nokogiri'
      end
      
      banner "knife libvirt storage pool show POOL (options)"
      
      def to_gb(kb)
        (kb/1073741824.0).round()
      end

      def run
        puts "Looking up storage pool.."
	host = "#{Chef::Config[:libvirt_uri]}"
		connection = Libvirt::open(host)
        @name_args.each do |pool_name|
          pool = connection.lookup_storage_pool_by_name(pool_name)
          puts "\tName: #{pool.name}"
          xml = Nokogiri::XML(pool.xml_desc)
	  puts "\tPath: #{xml.xpath('//target/path').inner_text}\tUUID: #{pool.uuid}"
          puts "\tVolumes: #{pool.num_of_volumes}"
          #puts "Autostart: #{pool.autostart?}"
          #puts "Persistent: #{pool.persistent?}"
          puts "\tCapacity: #{to_gb(pool.info.capacity)} GB"
          puts "\tAllocated: #{to_gb(pool.info.allocation)} GB"
          puts "\tAvailable: #{to_gb(pool.info.available)} GB"
          puts "-"*80
          puts
        end
      end
    end
    
    class LibvirtStorageVolumeList < Knife
      deps do
        require 'chef/knife/bootstrap'
        require 'libvirt'
        Chef::Knife::Bootstrap.load_deps
      end
      
      banner "knife libvirt storage volume list (options)"
      
      def to_mb(kb)
        (kb/1024.0).round()
      end
      
      def run
	puts "Listing volumes..."
        host = "#{Chef::Config[:libvirt_uri]}"
        connection = Libvirt::open(host)
        connection.list_storage_pools.each do |pool_name|
	  puts "-"*80
	  puts "\t#{pool_name}:"
          storage_pool = connection.lookup_storage_pool_by_name(pool_name)
          storage_pool.list_volumes.each do |volume|
            	vol = storage_pool.lookup_volume_by_name(volume)
		puts "\t\t#{volume} #{to_mb(vol.info.allocation)} MB/#{to_mb(vol.info.capacity)} MB"
          end
          puts "-"*80
        end
      end
      
	class LibvirtStorageVolumeShow < Knife
        	deps do
          		require 'chef/knife/bootstrap'
          		Chef::Knife::Bootstrap.load_deps
          		require 'libvirt'
        	end
    
        	banner "knife libvirt storage volume show POOL VOLUME (options)"

        	def to_mb(kb)
			(kb/1024.0).round()
		end
		def run
			puts "Looking up volume..."
			host = "#{Chef::Config[:libvirt_uri]}"
			connection = Libvirt::open(host)
          		@name_args.each_slice(2) do |pool_name, volume_name|
            		volume = connection.lookup_storage_pool_by_name(pool_name).lookup_volume_by_name(volume_name)
            		puts "-"*80
			puts "\tName: #{volume.name}"
            		puts "\tPool: #{volume.pool.name}"
         		puts
            		puts "\t\tCapacity:  #{to_mb(volume.info.capacity)} MB"
            		puts "\t\tAllocated: #{to_mb(volume.info.allocation)} MB"
            		puts "\t\tPath: #{volume.path}"
            		puts "\t\tKey:  #{volume.key}"
            		puts "-"*80
            		puts
		end
	end       
    end
  end
end
end
