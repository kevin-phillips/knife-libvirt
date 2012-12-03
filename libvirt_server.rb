class Chef
  class Knife
    class LibvirtServerList < Knife
    
    
     deps do
       require 'chef/knife/bootstrap'
       require 'libvirt'
       Chef::Knife::Bootstrap.load_deps
     end
            
      banner "knife libvirt server list (options)"
       
      def connect(host, path)
        host = "qemu+ssh://root@#{host}/system"
        connection = Libvirt::open(host)
      end

      def to_gb(kb)
        (kb/1073741824.0).round()
      end

      def to_mb(kb)
        (kb/1024.0).round()
      end

		def get_domain_interface_mac(domain)
			xml = domain.xml_desc(domain)
			match = /mac address=([a-fA-F0-9:]{17})/.match(xml)
			mac = match[1]
		end

		def get_domain_arch(domain)
			xml = domain.xml_desc(domain)
			match = /arch='*(.+?)'/.match(xml)
			arch = match[1]
		end


      def get_domain_info(domain,connection)
			states = ["No State","Active","Blocked","Paused","Shutting Down","Inactive","Crashed"]
			puts "\n\tName:\t#{domain.name}\tState:\t#{states[(domain.info.state)]}"
			puts "\t\tOS Type: #{domain.os_type}"
			puts "\t\tID:\t#{domain.id}\tUUID:\t#{domain.uuid}"
			puts "\t\tVCPU:\t#{domain.info.nr_virt_cpu} #{get_domain_arch(domain)} CPU @ #{connection.node_get_info.mhz} MHz"
			puts "\t\tUsed Memory:\t#{to_mb(domain.info.memory)} MB\tMax Memory:\t#{to_mb(domain.info.max_mem)} MB"
			puts
			puts "-"*80
      end
      
      def run
        host = Chef::Config[:libvirt_uri]
        connection = Libvirt::open(host)
			puts "\nHost:\t#{Chef::Config[:libvirt_host]}"
			puts "\tActive:\t#{connection.num_of_domains}\tInactive:\t#{connection.num_of_defined_domains}"
			puts
			puts "-"*80

			connection.list_domains.each do |domain_id|
        		domain = connection.lookup_domain_by_id(domain_id)
				get_domain_info(domain,connection)
        	end
        	connection.list_defined_domains.each do |domain_name|
        		domain = connection.lookup_domain_by_name(domain_name)
        		get_domain_info(domain,connection)
        	end
      end
    end

	

    class LibvirtServerCreate < Knife
	
	$script = FALSE

      deps do
        require 'chef/knife/bootstrap'
        require 'nokogiri'
        require 'libvirt'
        Chef::Knife::Bootstrap.load_deps
      end
            
      banner "knife libvirt server create (options)"
      
	def get_mac(domain)
		xml = domain.xml_desc(domain)
		match = /mac address='([a-fA-F0-9:]{17})/.match(xml)
		mac = match[1]
	end
	def prompt(*args)
		STDIN.gets
	end
      
	  option :memory,
        :short => "-m MEMORY",
        :long => "--memory MEMORY",
        :description => "The amount of RAM in MB for new server",
        :proc => Proc.new { |f| Chef::Config[:knife][:memory] = f },
        :default => "1024"
      
	  option :cpus,
		:short => "-c CPUS",
		:long => "--cpus CPUS",
		:description => "Number of cpus for new server",
		:proc => Proc.new { |c| Chef::Config[:knife][:cpus] = c },
		:default => "1"

      option :system,
        :short => "-s SYSTEM ",
        :long => "--system SYSTEM",
        :description => "A system filename",
        :proc => Proc.new { |i| Chef::Config[:knife][:system] = i }
      
      option :hostname,
        :short => "-n HOSTNAME",
        :long => "--name HOSTNAME",
        :description => "The host name of the new server",
		:proc => Proc.new { |h| Chef::Config[:knife][:hostname] = h }
        
      option :domain,
        :short => "-d DOMAIN",
        :long => "--domain DOMAIN",
        :description => "Domain name of the new server"
        
      option :bootstrap,
        :short => "-b BOOTSTRAP",
        :long => "--bootstrap BOOTSTRAP_FILENAME",
        :description => "Bootstrap a distro using a template",
        :proc => Proc.new { |b| Chef::Config[:knife][:distro] = b },
        :default => "ubuntu10.04-gems"		

		option :script,
			:short 	=>	"-S",
			:long	=>	"--script",
			:description	=> "No prompts for use in a script",
			:proc	=>	Proc.new { |s| script = TRUE }

      def get_server_xml_erb
	memory = Chef::Config[:knife][:memory].to_i
	memory = memory**2	
	<<-server
        <domain type='kvm'>
          <name><%="#{Chef::Config[:knife][:hostname]}" %></name>
          <memory><%="#{memory}"%></memory>
          <currentMemory><%="#{memory}"%></currentMemory>
          <vcpu><%="#{Chef::Config[:knife][:cpus]}"%></vcpu>
          <os>
            <type arch='x86_64' machine='pc-0.10'>hvm</type>
            <boot dev='network'/>
          </os>
          <features>
            <acpi/>
            <apic/>
            <pae/>
          </features>
          <clock offset='utc'/>
          <on_poweroff>destroy</on_poweroff>
          <on_reboot>restart</on_reboot>
          <on_crash>restart</on_crash>
          <devices>
            <emulator>/usr/bin/kvm</emulator>
            <disk type='file' device='disk'>
              <driver name='qemu' type='qcow2'/>
              <source file='<%="#{Chef::Config[:libvirt_storage_path]}/#{Chef::Config[:knife][:hostname]}.img"%>'/>
              <target dev='vda' bus='virtio'/>
            </disk>       
            <interface type='network'>
              <source network='virtlab'/>
              <model type='virtio'/>
            </interface>
            <input type='mouse' bus='ps2'/>
            <graphics type='vnc' port='-1' autoport='yes'/>
            <sound model='ich6'/>
            <video>
              <model type='cirrus' vram='9216' heads='1'/>
            </video>
          </devices>
        </domain>
        server
      end
      
     def run
		host = Chef::Config[:libvirt_uri]
		connection = Libvirt::open(host)
		new_server_xml = ERB.new(get_server_xml_erb).result
		server = connection.define_domain_xml(new_server_xml)
		mac=get_mac(server)
		request_response = open("http://10.1.4.194/networkmanager/inc/request_ip?rr_name=#{Chef::Config[:knife][:hostname]}&mac_address=#{mac}")
		puts "created #{Chef::Config[:knife][:hostname]} with #{Chef::Config[:knife][:cpus]} CPUS and #{Chef::Config[:knife][:memory]} MB RAM which has the MAC address of #{mac} with DNS record #{request_response.read}"
		if $script==FALSE
			puts "\n\nThe system has been created, but has yet to be started. Please take some time to add the system Cobbler. Press [enter] when you are ready to continue..."
			response = STDIN.gets
		end
		server.create
	end
      
    end
  end
end

