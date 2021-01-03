
ENV['RAILS_ENV'] = 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'net/ssh/test'
require 'net/sftp'
require 'webmock/minitest'

require 'sidekiq/testing'
Sidekiq::Testing.fake!

require 'simplecov'
SimpleCov.start

class ActiveSupport::TestCase
  include Net::SSH::Test

  http_stubs = [
    {
      url: 'https://api.vultr.com/v1/plans/list',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/plans_list.json'
    },
    {
      url: 'https://api.vultr.com/v1/server/list?SUBID=123456789',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/server_list_id.json'
    },
    {
      url: 'https://api.vultr.com/v1/dns/list',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/dns_list.json'
    },
    {
      url: 'https://api.vultr.com/v1/dns/records?domain=openode.io',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/domain_records_openode.json'
    },
    {
      url: 'https://api.vultr.com/v1/dns/records?domain=what.is',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/domain_records_what_is.json'
    },
    {
      url: 'https://api.vultr.com/v1/regions/list',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/regions_list.json'
    },
    {
      url: 'https://api.vultr.com/v1/os/list',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/os_list.json'
    },
    {
      url: 'https://api.vultr.com/v1/startupscript/list',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/startup_scripts_list.json'
    },
    {
      url: 'https://api.vultr.com/v1/firewall/group_list',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/firewall_group_list.json'
    },
    {
      url: 'https://api.vultr.com/v1/server/destroy',
      method: :post,
      with: {
        body: { 'SUBID' => 'mysubid1' }
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/empty.json'
    },
    {
      url: 'https://api.vultr.com/v1/dns/create_domain',
      method: :post,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/empty_str.json'
    },
    {
      url: 'https://api.vultr.com/v1/dns/create_record',
      method: :post,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/empty_str.json'
    },
    {
      url: 'https://api.vultr.com/v1/dns/delete_record',
      method: :post,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/empty_str.json'
    },
    {
      url: 'https://api.vultr.com/v1/sshkey/destroy',
      method: :post,
      with: {
        body: { 'SSHKEYID' => 'mysshkeyid' }
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/empty.json'
    },
    {
      url: 'https://api.vultr.com/v1/sshkey/create',
      method: :post,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/ssh_key_create.json'
    },
    {
      url: 'https://api.vultr.com/v1/server/create',
      method: :post,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/server_create.json'
    },
    {
      url: 'http://95.180.134.210/',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/openode_ready.txt'
    },
    {
      url: 'http://95.180.134.211/',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/cloud_provider/vultr/empty.json'
    },
    {
      url: 'https://api.mailgun.net/v3/openode.io/events?event=failed&limit=300',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/mailgun/failed_events.json'
    },
    {
      url: 'https://api.uptimerobot.com/v2/getMonitors',
      method: :post,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/uptime_robot/get_monitors.json'
    },
    {
      url: 'https://api.openode.io/account/getToken',
      method: :post,
      with: {
        body: { 'email' => 'mymail@openode.io', 'password' => '1234561!' }
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/openode_api/front/get_token_exists.json'
    },
    {
      url: 'https://api.openode.io/instances/testsite/stop?location_str_id=canada',
      method: :post,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/openode_api/instances_stop.json'
    },
    {
      url: 'https://api.openode.io/instances/testsite/destroy-storage?location_str_id=canada',
      method: :post,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/openode_api/destroy-storage.json'
    },
    {
      url: 'https://ipnpb.paypal.com/cgi-bin/webscr?cmd=_notify-validate',
      method: :post,
      with: {
        body: ""
      },
      content_type: 'text/html',
      response_status: 200,
      response_path: 'test/fixtures/http/payment/paypal/verified.txt'
    },
    {
      url: 'https://ipnpb.paypal.com/cgi-bin/webscr?cmd=_notify-validate',
      method: :post,
      with: {
        body: "{\"mc_gross\":\"2.00\",\"protection_eligibility\":\"Eligible\",\"address_status\":\"confirmed\",\"payer_id\":\"7GBYJ8696D738\",\"address_street\":\"145 ROAD\",\"payment_date\":\"04:15:29 Oct 26, 2019 PDT\",\"payment_status\":\"Completed\",\"charset\":\"windows-1252\",\"address_zip\":\"S7 4LE\",\"first_name\":\"Elvis\",\"option_selection1\":\"200 Credits\",\"mc_fee\":\"0.17\",\"address_country_code\":\"GB\",\"address_name\":\"Martin L\",\"notify_version\":\"3.9\",\"custom\":113629430,\"payer_status\":\"verified\",\"business\":\"info@openode.io\",\"address_country\":\"Canada\",\"address_city\":\"Mtl\",\"quantity\":\"1\",\"verify_sign\":\"AZuQXZZkuk7frhfirfxxTkj0BDLGARX0B64SyhEeW2wnN8KZ.HyIs8r2\",\"payer_email\":\"123456@gmail.com\",\"option_name1\":\"Amount of Credits\",\"txn_id\":\"1XN491692K554135N\",\"payment_type\":\"instant\",\"last_name\":\"LL-S\",\"address_state\":\"\",\"receiver_email\":\"info@openode.io\",\"payment_fee\":\"0.17\",\"shipping_discount\":\"0.00\",\"insurance_amount\":\"0.00\",\"receiver_id\":\"JS2SF9ESDQKCG\",\"txn_type\":\"web_accept\",\"item_name\":\"opeNode Credits Purchase\",\"discount\":\"0.00\",\"mc_currency\":\"USD\",\"item_number\":\"\",\"residence_country\":\"CA\",\"shipping_method\":\"Default\",\"transaction_subject\":\"\",\"payment_gross\":\"2.00\",\"ipn_track_id\":\"b41138e1a5519\"}"
      },
      content_type: 'text/html',
      response_status: 200,
      response_path: 'test/fixtures/http/payment/paypal/verified.txt'
    },
    {
      url: 'https://ipnpb.paypal.com/cgi-bin/webscr?cmd=_notify-validate',
      method: :post,
      with: {
        body: "\"\""
      },
      content_type: 'text/html',
      response_status: 200,
      response_path: 'test/fixtures/http/payment/paypal/invalid.txt'
    },
    {
      url: 'https://ipnpb.paypal.com/cgi-bin/webscr?cmd=_notify-validate',
      method: :post,
      with: {
        body: "{\"mc_gross\":\"2.00\",\"protection_eligibility\":\"Eligible\",\"address_status\":\"confirmed\",\"payer_id\":\"7GBYJ8696D738\",\"address_street\":\"145 ROAD\",\"payment_date\":\"04:15:29 Oct 26, 2019 PDT\",\"payment_status\":\"not completed\",\"charset\":\"windows-1252\",\"address_zip\":\"S7 4LE\",\"first_name\":\"Elvis\",\"option_selection1\":\"200 Credits\",\"mc_fee\":\"0.17\",\"address_country_code\":\"GB\",\"address_name\":\"Martin L\",\"notify_version\":\"3.9\",\"custom\":\"10000\",\"payer_status\":\"verified\",\"business\":\"info@openode.io\",\"address_country\":\"Canada\",\"address_city\":\"Mtl\",\"quantity\":\"1\",\"verify_sign\":\"AZuQXZZkuk7frhfirfxxTkj0BDLGARX0B64SyhEeW2wnN8KZ.HyIs8r2\",\"payer_email\":\"123456@gmail.com\",\"option_name1\":\"Amount of Credits\",\"txn_id\":\"1XN491692K554135N\",\"payment_type\":\"instant\",\"last_name\":\"LL-S\",\"address_state\":\"\",\"receiver_email\":\"info@openode.io\",\"payment_fee\":\"0.17\",\"shipping_discount\":\"0.00\",\"insurance_amount\":\"0.00\",\"receiver_id\":\"JS2SF9ESDQKCG\",\"txn_type\":\"web_accept\",\"item_name\":\"opeNode Credits Purchase\",\"discount\":\"0.00\",\"mc_currency\":\"USD\",\"item_number\":\"\",\"residence_country\":\"CA\",\"shipping_method\":\"Default\",\"transaction_subject\":\"\",\"payment_gross\":\"2.00\",\"ipn_track_id\":\"b41138e1a5519\"}"
      },
      content_type: 'text/html',
      response_status: 200,
      response_path: 'test/fixtures/http/payment/paypal/verified.txt'
    },
    {
      url: 'http://github.com/openode-io/openode-cli',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'text/html',
      response_status: 200,
      response_path: 'test/fixtures/http/open_source/openode_cli.txt'
    },
    {
      url: 'https://github.com/openode-io/openode-cli',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'text/html',
      response_status: 200,
      response_path: 'test/fixtures/http/open_source/openode_cli.txt'
    },
    {
      url: 'http://github.com/openode-io/openode-bad',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'text/html',
      response_status: 200,
      response_path: 'test/fixtures/http/open_source/openode_bad.txt'
    },
    {
      url: 'http://github.com/myrepo',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'text/html',
      response_status: 200,
      response_path: 'test/fixtures/http/open_source/openode_cli.txt'
    },
    {
      url: 'http://github.com/invalid',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'text/html',
      response_status: 200,
      response_path: 'test/fixtures/http/open_source/openode_bad.txt'
    },
    {
      url: 'https://api.digitalocean.com/v2/kubernetes/clusters?page=1&per_page=20',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/do/clusters.json'
    },
    {
      url: 'https://api.digitalocean.com/v2/kubernetes/clusters/bd5f5959-5e1e-4205-a714-a914373942af/node_pools',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/do/cluster_node_pools.json'
    },
    {
      url: 'https://api.digitalocean.com/v2/droplets?page=1&per_page=20',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/do/droplets.json'
    },
    {
      url: 'https://api.digitalocean.com/v2/kubernetes/clusters/bd5f5959-5e1e-4205-a714-a914373942ae/node_pools',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/do/get_node_pools.json'
    },
    {
      url: 'https://api.digitalocean.com/v2/kubernetes/clusters/bd5f5959-5e1e-4205-a714-a914373942ae/node_pools/cdda885e-7663-40c8-bc74-3a036c66545d',
      method: :put,
      with: {
        body: "{\"name\":\"frontend-pool\",\"size\":\"s-1vcpu-2gb\",\"count\":4,\"tags\":[\"k8s\",\"k8s:bd5f5959-5e1e-4205-a714-a914373942af\",\"k8s:worker\",\"production\",\"web-team\"],\"labels\":null,\"auto_scale\":null,\"min_nodes\":null,\"max_nodes\":null}"
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/do/empty.txt'
    },
    {
      url: 'https://api.digitalocean.com/v2/registry/openode_prod/repositories?page=1&per_page=20',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/do/get_registry_repos.json'
    },
    {
      url: 'https://api.digitalocean.com/v2/registry/openode_prod/repositories/repo-1/tags?page=1&per_page=20',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/do/get_repo_tags.json'
    },
    {
      url: 'https://api.digitalocean.com/v2/registry/openode_prod/repositories/repo-1/tags/sitename--111--123456',
      method: :delete,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/do/empty.txt'
    },
    {
      url: 'https://api.github.com/repos/openode-io/addons/git/trees/master?recursive=true',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/addons/repo_tree.json'
    },
    {
      url: 'https://raw.githubusercontent.com/openode-io/addons/master/caching/redis-caching/config.json',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/addons/config.json'
    },
    {
      url: 'https://api.openode.io/instances/testsite/addons/980191099/offline?location_str_id=canada',
      method: :post,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/openode_api/empty.json'
    },
    {
      url: 'https://api.neverbounce.com/v4.2/single/check',
      method: :get,
      with: {
        body: { "email": "myadmin@thisisit.com", "key": "secret_xxxxxx" }
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/neverbounce/valid.json'
    },
    {
      url: 'https://api.neverbounce.com/v4.2/single/check',
      method: :get,
      with: {
        body: { "email": "myinvalidemail@gmail.com", "key": "secret_xxxxxx" }
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/neverbounce/invalid.json'
    },
    {
      url: 'https://api-m.paypal.com/v1/oauth2/token',
      method: :post,
      with: {
        body: { "grant_type": "client_credentials" }
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/paypal/access_token.json'
    },
    {
      url: 'https://api-m.paypal.com/v1/billing/subscriptions/MY_SUB',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/paypal/my_sub.json'
    },
    {
      url: 'https://api-m.paypal.com/v1/billing/subscriptions/I-19RUCRSR776E',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/paypal/valid.json'
    },
    {
      url: 'https://ipnpb.paypal.com/cgi-bin/webscr?cmd=_notify-validate',
      method: :post,
      with: {
        body: "payment_cycle=Daily&txn_type=recurring_payment_profile_cancel&last_name=Levesque&next_payment_date=N/A&residence_country=CA&initial_payment_amount=0.00&currency_code=USD&time_created=18%3A44%3A29+Jan+02%2C+2021+PST&verify_sign=Ab9GqN77tIrXe20oyfXtzTVqk4q1ADZ0S5jAQI9MLW3761RKjjSJYfdv&period_type=+Regular&payer_status=unverified&tax=0.00&payer_email=levesque.martin%40gmail.com&first_name=Martin&receiver_email=info%40openode.io&payer_id=G3A62CTSVEHRW&product_type=1&shipping=0.00&amount_per_cycle=1.00&profile_status=Cancelled&charset=windows-1252&notify_version=3.9&amount=1.00&outstanding_balance=0.00&recurring_payment_id=I-C07GLHXGP65Y&product_name=openode+test&ipn_track_id=924c4eb589c62\n\n"
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/payment/paypal/verified.txt'
    },
    {
      url: 'https://api-m.paypal.com/v1/billing/subscriptions/I-C07GLHXGP65Y',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/paypal/valid.json'
    },
    {
      url: 'https://ipnpb.paypal.com/cgi-bin/webscr?cmd=_notify-validate',
      method: :post,
      with: {
        body: "payment_cycle=Daily&txn_type=recurring_payment_profile_cancel&last_name=Levesque&next_payment_date=N/A&residence_country=CA&initial_payment_amount=0.00&currency_code=USD&time_created=18%3A44%3A29+Jan+02%2C+2021+PST&verify_sign=Ab9GqN77tIrXe20oyfXtzTVqk4q1ADZ0S5jAQI9MLW3761RKjjSJYfdv&period_type=+Regular&payer_status=unverified&tax=0.00&payer_email=levesque.martin%40gmail.com&first_name=Martin&receiver_email=info%40openode.io&payer_id=G3A62CTSVEHRW&product_type=1&shipping=0.00&amount_per_cycle=1.00&profile_status=Cancelled&charset=windows-1252&notify_version=3.9&amount=1.00&outstanding_balance=0.00&recurring_payment_id=I-C07GLHXGP65INACTIVE&product_name=openode+test&ipn_track_id=924c4eb589c62\n"
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/payment/paypal/verified.txt'
    },
    {
      url: 'https://api-m.paypal.com/v1/billing/subscriptions/I-C07GLHXGP65INACTIVE',
      method: :get,
      with: {
        body: {}
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/paypal/canceled.json'
    },
    {
      url: 'https://ipnpb.paypal.com/cgi-bin/webscr?cmd=_notify-validate',
      method: :post,
      with: {
        body: "mc_gross=1.00&period_type=+Regular&outstanding_balance=0.00&next_payment_date=02%3A00%3A00+Jan+03%2C+2021+PST&protection_eligibility=Eligible&payment_cycle=Daily&address_status=confirmed&tax=0.00&payer_id=G3A62CTSVEHRW&address_street=6680+Baillargeon&payment_date=18%3A46%3A06+Jan+02%2C+2021+PST&payment_status=Completed&product_name=openode+test&charset=windows-1252&recurring_payment_id=I-C07GLHXGP65Y&address_zip=j4z1s8&first_name=Martin&mc_fee=0.10&address_country_code=CA&address_name=Martin+Levesque&notify_version=3.9&amount_per_cycle=1.00&payer_status=unverified&currency_code=USD&business=info%40openode.io&address_country=Canada&address_city=Brossard&verify_sign=Aml20njl9DXrAMgHcc7m0EmUUiqwAVy7q.wZJBb.nXkZ.0M.0V5lagCL&payer_email=levesque.martin%40gmail.com&initial_payment_amount=0.00&profile_status=Active&amount=1.00&txn_id=73V47872D10092911&payment_type=instant&last_name=Levesque&address_state=QC&receiver_email=info%40openode.io&payment_fee=0.10&receiver_id=FS2SL9ESDQKCG&txn_type=recurring_payment&mc_currency=USD&residence_country=CA&receipt_id=0483-1472-9192-6690&transaction_subject=openode+test&payment_gross=1.00&shipping=0.00&product_type=1&time_created=18%3A44%3A29+Jan+02%2C+2021+PST&ipn_track_id=5ba41a09b532c\n"
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/payment/paypal/verified.txt'
    },
    {
      url: 'https://api-m.paypal.com/v1/billing/subscriptions/I-CCCANCELGLHXGP65Y/cancel',
      method: :post,
      with: {
        body: "{\"reason\": \"N/A\"}"
      },
      content_type: 'application/json',
      response_status: 200,
      response_path: 'test/fixtures/http/paypal/empty.txt'
    }
  ]

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  setup do
    http_stubs.each do |http_stub|
      stub_request(http_stub[:method], http_stub[:url])
        .with(body: http_stub[:with][:body])
        .to_return(status: http_stub[:response_status],
                   body: IO.read(http_stub[:response_path]),
                   headers: { content_type: http_stub[:content_type] })
    end
  end

  def set_dummy_secrets_to(servers)
    servers.each do |server|
      server.save_secret!(
        user: 'myuser',
        password: 'mypass',
        private_key: 'toto'
      )
    end
  end

  def reset_all_extra_storage
    WebsiteLocation.all.each do |wl|
      wl.extra_storage = 0
      wl.save!
    end
  end

  def prepare_cloud_provider_manager
    CloudProvider::Manager.clear_instance
    CloudProvider::Manager.instance
  end

  def prepare_ssh_session(cmd, output, exit_code = 0)
    story do |session|
      channel = session.opens_channel
      channel.sends_exec cmd
      channel.gets_data output
      channel.gets_exit_status(exit_code)
      channel.gets_close
      channel.sends_close
    end
  end

  def prepare_ssh_ensure_remote_repository(website)
    prepare_ssh_session("mkdir -p #{website.repo_dir}", '')
  end

  def prepare_send_remote_repo(website, arch_filename, output)
    cmd = DeploymentMethod::DockerCompose.new.uncompress_remote_archive(
      repo_dir: website.repo_dir,
      archive_path: "#{website.repo_dir}#{arch_filename}"
    )

    prepare_ssh_session(cmd, output)
  end

  def begin_sftp
    Remote::Sftp.set_conn_test('dummy')
  end

  def expect_file_sent(filename)
    Remote::Sftp.get_test_uploaded_files.any? { |f| f[:remote_file_path] == filename }
  end

  def begin_ssh
    Remote::Ssh.set_conn_test(connection)
  end

  def default_website
    Website.find_by site_name: 'testsite'
  end

  def default_custom_domain_website
    Website.find_by site_name: 'www.what.is'
  end

  def default_kube_website
    Website.find_by type: Website::TYPE_KUBERNETES
  end

  def default_website_location
    default_website.website_locations.first
  end

  def dummy_ssh_configs
    {
      host: 'test.com',
      secret: {
        user: 'user',
        password: '123456'
      },
      website: default_website,
      website_location: default_website_location
    }
  end

  def add_collaborator_for(user, website, perm = Website::PERMISSION_ROOT)
    Collaborator.create!(
      user: user,
      website: website,
      permissions: [perm]
    )
  end

  def default_runner_configs
    {
      host: 'test.com',
      secret: {
        user: 'user',
        password: '123456'
      },
      website: default_website,
      website_location: default_website_location
    }
  end

  def prepare_default_execution_method
    set_dummy_secrets_to(LocationServer.all)
    runner = DeploymentMethod::Runner.new('docker', 'cloud', default_runner_configs)
    runner.get_execution_method
  end

  def prepare_kubernetes_runner(website, website_location)
    cloud_provider_manager = CloudProvider::Manager.instance
    build_server = cloud_provider_manager.docker_build_server

    configs = {
      website: website,
      website_location: website_location,
      host: build_server['ip'],
      secret: {
        user: build_server['user'],
        private_key: build_server['private_key']
      }
    }

    runner = DeploymentMethod::Runner.new(Website::TYPE_KUBERNETES, 'cloud', configs)

    runner.init_execution!("Deployment")

    runner
  end

  def prepare_default_ports
    website_location = default_website_location
    website_location.port = 33_129
    website_location.second_port = 33_121
    website_location.running_port = 33_129
    website_location.save!
  end

  def prepare_default_kill_all(dep_method)
    cmd = dep_method.global_containers({})
    prepare_ssh_session(cmd, IO.read('test/fixtures/docker/global_containers.txt'))
    prepare_ssh_session(dep_method.kill_global_container(id: 'b3621dd9d4dd'), 'killed b3621dd9d4dd')
    prepare_ssh_session(dep_method.kill_global_container(id: '32bfe26a2712'), 'killed 32bfe26a2712')
  end

  def dep_event_exists?(events, status, update)
    events.any? { |e| e['update'].include?(update) && e['status'] == status }
  end

  def prepare_logs_container(dep_method, website, container_id, result = 'done_logs')
    website.container_id = nil
    prepare_ssh_session(dep_method.logs(container_id: container_id, nb_lines: 10_000,
                                        website: website),
                        result)
  end

  def prepare_get_docker_compose(dep_method, website)
    cmd_get_docker_compose = dep_method.get_file(repo_dir: website.repo_dir,
                                                 file: 'docker-compose.yml')
    basic_docker_compose = IO.read('test/fixtures/docker/docker-compose.txt')
    prepare_ssh_session(cmd_get_docker_compose, basic_docker_compose)
  end

  def prepare_front_container(dep_method, website, website_location, response = '')
    options = {
      in_port: 80,
      website: website,
      website_location: website_location,
      ensure_exit_code: 0,
      limit_resources: true
    }

    prepare_ssh_session(dep_method.front_container(options), response)
  end

  def prepare_docker_compose(dep_method, front_container_id, response = '')
    cmd = dep_method.docker_compose(front_container_id: front_container_id)
    prepare_ssh_session(cmd, response)
  end

  def expect_global_container(dep_method)
    cmd = dep_method.global_containers({})
    prepare_ssh_session(cmd, IO.read('test/fixtures/docker/global_containers.txt'))
  end

  def prepare_forbidden_test(permission)
    w = Website.find_by site_name: 'www.what.is'

    collaborator = add_collaborator_for(default_user, w, permission)

    [w, collaborator]
  end

  def default_user
    User.find_by email: 'myadmin@thisisit.com'
  end

  def base_params(opts = {})
    {
      version: InstancesController::MINIMUM_CLI_VERSION,
      location_str_id: opts[:location_str_id] || 'canada'
    }
  end

  def sample_open_source_attributes(status = Website::OPEN_SOURCE_STATUS_APPROVED)
    {
      'status' => status,
      'title' => 'helloworld',
      'description' => " asdf " * 31,
      'repository_url' => "https://github.com/openode-io/openode-cli"
    }
  end

  def default_headers_auth
    headers_auth('1234s56789')
  end

  def headers_auth(token)
    {
      "x-auth-token": token
    }
  end

  def super_admin_headers_auth
    {
      "x-auth-token": '12345678'
    }
  end

  def set_website_certs(website, opts = {})
    website.configs ||= {}
    website.configs['SSL_CERTIFICATE_PATH'] = opts[:cert] || 'cert/crt'
    website.configs['SSL_CERTIFICATE_KEY_PATH'] = opts[:key] || 'cert/key'
    website.save!
  end

  def set_reference_image_website(website, referenced_website)
    website.configs ||= {}
    website.configs['REFERENCE_WEBSITE_IMAGE'] = referenced_website.site_name
    website.save!
  end

  def invoke_task(task_name)
    OpenodeApi::Application.load_tasks unless defined?(Rake::Task)

    Rake::Task[task_name].execute
  end

  def invoke_all_jobs
    Sidekiq::Worker.drain_all
  end

  def clear_all_queued_jobs
    Sidekiq::Worker.clear_all
  end

  def reset_emails
    ActionMailer::Base.deliveries.clear
  end

  # Add more helper methods to be used by all tests here...
end
