class PopulateWebsiteAddonPorts < ActiveRecord::Migration[6.0]
  def change
    WebsiteAddon.all.each do |wa|
      if wa.obj && !wa.obj['ports']
        wa.obj['ports'] = wa.ports
        wa.save
        end
    end
  end
end
