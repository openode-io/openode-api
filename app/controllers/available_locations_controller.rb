require 'droplet_kit'

class AvailableLocationsController < ApplicationController
  api!
  def index
    type = params['type'] || 'kubernetes'

    manager = if type
                # TODO: -> deprecate next line
                real_type = type == 'docker' ? 'internal' : type
                real_type = 'kubernetes' unless %w[internal kubernetes gcloud_run].include?(real_type)

                puts "real type -> #{real_type}"

                CloudProvider::Manager.instance.first_of_type(real_type)
              else
                CloudProvider::Manager.instance
              end

    puts "manager --> #{manager.inspect}"

    json(manager.available_locations)
  end

  api :GET, 'global/available-locations/:str_id/ips'
  description 'Retrieve the server IPs at a given location.'
  param :str_id, String, desc: 'Location str id, from /global/available-locations', required: true
  def ips
    assert ENV['DO_ACCESS_TOKEN']
    cache_key = "/api/global/available-locations/"

    result = Rails.cache.fetch("#{cache_key}#{params['str_id']}/ips", expires_in: 10.minutes) do
      client = DropletKit::Client.new(access_token: ENV['DO_ACCESS_TOKEN'])
      clusters = client.kubernetes_clusters.all

      looking_for_cluster = "k8s-#{params['str_id']}"
      cluster = clusters.find { |c| c.name == looking_for_cluster }
      return json([]) unless cluster

      all_droplets = client.droplets.all
      pools = client.kubernetes_clusters.node_pools(id: cluster.id)

      pools.map do |pool|
        pool.nodes.map do |node|
          droplet = all_droplets.find { |d| d.name == node.name }
          public_network = droplet&.networks&.v4&.find { |n| n.type == 'public' }

          public_network ? public_network.ip_address : nil
        end
            .select(&:present?)
      end
           .flatten
    end

    json(result)
  end
end
