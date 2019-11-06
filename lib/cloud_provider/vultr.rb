require 'vultr'
require 'countries'

Vultr.api_key = ENV['']

module CloudProvider
  class Vultr < Base
    TYPE = 'private-cloud'

    def initialize(configs)
      ::Vultr.api_key = configs['api_key']

      initialize_locations
    end

    def deployment_protocol
      'ssh'
    end

    def limit_resources?
      false
    end

    def type
      Vultr::TYPE
    end

    def stop(options = {})
      # stopping an instance requires to kill the machine and remove ssh keys

      website = options[:website]
      website_location = options[:website_location]

      return unless website.data

      instance_info = website.andand.data['privateCloudInfo']

      # make sure to destroy the machine:
      if instance_info
        sub_id = instance_info['SUBID']
        ssh_key_id = instance_info['SSHKEYID']

        if sub_id
          ::Vultr::Server.destroy(SUBID: sub_id)
          website.data['privateCloudInfo']['SUBID'] = nil
          website.save
        end

        if ssh_key_id
          ::Vultr::SSHKey.destroy(SSHKEYID: ssh_key_id)
          website.data['privateCloudInfo']['SSHKEYID'] = nil
          website.save
        end

        website.data.delete 'privateCloudInfo'
        website.save
      end

      # destroy the server in the models
      return unless website_location.location_server

      location_server = website_location.location_server
      website_location.location_server = nil
      website_location.save

      location_server.destroy
    end

    def result_to_array(result)
      result[:result].keys
                     .map { |key| result[:result][key] }
    end

    def os_list
      result_to_array(::Vultr::OS.list)
    end

    def server_info(opts = {})
      ::Vultr::Server.list(opts)[:result]
    end

    def create_openode_server!(website_location, info)
      return if !info || !info['main_ip'] || info['main_ip'] == '0.0.0.0'

      website_location.add_server!(
        ip: info['main_ip'],
        ram_mb: info['ram'].to_i,
        cpus: info['vcpu_count'].to_i,
        disk_gb: info['disk'].scan(/\d/).join('').to_i,
        cloud_type: 'private-cloud'
      )
    end

    def save_password(website_location, location_server, info)
      # private - public keys should have been created already
      assert website_location.secret
      assert website_location.secret[:public_key]
      assert website_location.secret[:private_key]

      return unless location_server

      return if !info || info['default_password'].blank? ||
                info['default_password'] == 'not supported'

      return if info['main_ip'].blank? || info['main_ip'] == '0.0.0.0'

      # save info + add public and private keys
      location_server.save_secret!(
        info: info,
        public_key: website_location.secret[:public_key],
        private_key: website_location.secret[:private_key]
      )
    end

    def find_os(name, platform)
      os_list
        .find { |os| os['name'].include?(name) && os['name'].include?(platform) }
    end

    def startup_scripts_list
      result_to_array(::Vultr::StartupScript.list)
    end

    def find_startup_script(name)
      startup_scripts_list
        .find { |script| script['name'] == name }
    end

    def find_firewall_group(description)
      result_to_array(::Vultr::Firewall.group_list).find { |f| f['description'] == description }
    end

    def create_ssh_key!(name, public_key)
      ::Vultr::SSHKey.create(name: name, ssh_key: public_key)[:result]['SSHKEYID']
    end

    def self.get_entity_id(str, delimiter = '-')
      str.split(delimiter).last
    end

    def allocate(options = {})
      assert options[:website]
      assert options[:website_location]
      website = options[:website]
      website_location = options[:website_location]

      os = find_os('Debian 9', 'x64') # TODO: make it a parameter
      script = find_startup_script("website-#{website.id}") ||
               find_startup_script('init base debian') # TODO: +parameter

      firewall = find_firewall_group('base') # TODO: +parameter

      ssh_key = website_location.gen_ssh_key!
      vultr_ssh_key_id = create_ssh_key!("website-#{website.site_name}-#{website.id}",
                                         ssh_key[:public_key])

      server = {
        DCID: Vultr.get_entity_id(website_location.location.str_id),
        VPSPLANID: Vultr.get_entity_id(website.account_type),
        OSID: os['OSID'],
        SCRIPTID: script['SCRIPTID'],
        label: website_location.root_domain,
        hostname: website_location.root_domain,
        notify_activate: 'yes',
        FIREWALLGROUPID: firewall['FIREWALLGROUPID'],
        SSHKEYID: vultr_ssh_key_id
      }

      result = ::Vultr::Server.create(server)[:result]
      result['SSHKEYID'] = vultr_ssh_key_id

      website.data ||= {}
      website.data['privateCloudInfo'] = result
      website.save
    end

    def available_locations
      # string.parameterize
      regions = ::Vultr::Regions.list
      result = regions[:result]

      result.keys
            .map do |key|
        current_location = result[key]

        country_code = result[key]['country']
        country = ISO3166::Country.new(country_code)
        country_name = country.data['name']

        fullname = "#{current_location['name']} " \
                   "(#{country_name}, #{current_location['continent']})"

        {
          str_id: "#{current_location['name']} #{current_location['DCID']}".parameterize,
          full_name: fullname,
          country_fullname: country_name,
          cloud_provider: 'vultr'
        }
      end
    end

    def plans
      return @plans if @plans

      @plans = ::Vultr::Plans.list[:result]
                             .map do |_key, plan|
        id = "#{plan['ram']}-MB #{plan['VPSPLANID']}".parameterize.upcase
        price_per_month = plan['price_per_month'].to_f

        cost_per_hour = if price_per_month * 0.10 < 3
                          (price_per_month + 3.0) / 31.0 / 24.0
                        else
                          (price_per_month / 31.0 / 24.0) * 1.10
        end

        {
          id: id,
          internal_id: id,
          short_name: id,
          type: 'private-cloud',
          cost_per_hour: cost_per_hour,
          cost_per_month: cost_per_hour * 31.0 * 24.0,
          VPSPLANID: plan['VPSPLANID'],
          name: plan['name'],
          vcpu_count: plan['vcpu_count'],
          ram: plan['ram'].to_i,
          disk: plan['disk'].to_f,
          bandwidth: plan['bandwidth'].to_f,
          bandwidth_gb: plan['bandwidth_gb'].to_f,
          plan_type: plan['plan_type'],
          windows: plan['windows'],
          available_locations: plan['available_locations']
        }
      end

      @plans = @plans.select { |plan| plan[:plan_type] == 'SSD' }

      @plans
    end

    def plans_at(location_str_id)
      location_id = location_str_id.split('-').last.to_i

      plans
        .select { |plan| plan[:available_locations].include?(location_id) }
    end
  end
end
