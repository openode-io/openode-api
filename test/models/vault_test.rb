require 'test_helper'

class VaultTest < ActiveSupport::TestCase
  test "location server based vault" do
    ls = LocationServer.first

    private_key = """-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAt920A6VTTmAaTxccbg/Bp/hb8eN9o0tttpsXy5gKVS79skPl
inLz10ZUw6y4cmiewWufPUdOdlgjHyrt7YHBJ1EIVG8eBazT7UCJbDOOeF5ATkGh
PIBDmA7e8PlWF7lvORFzT59EHPBHGxNYmuQNqcVobfp66IVq06ESmlUCXGQdKLzg
HncDQXsOw9gxsQPZd3gsdKwHhVtgneg0Zp0TynlWu7A3sj1GvCBqSrnjG/eKSw7Z
y7TjJly1VILasD6lVl9nheEXEIqUUaxnVxfGw32aAObTcerG7gx7EACCHqUbM5Us
LohxqWczM3E3GHDqNsDIX8F9JCsDUvbhV/vFtQQDAQABAoIBAEHik+rqg3fY4BSP
N4TI6KAEAw5+cjrdgIb6tGAkLy+vEwGaCtq9rlrpvN4ROlbk3l547irLLnaBxrQY
cgG1iT1JcC6xUpS+BYLyqUu4fcjsHSbtpZVEcPQ//+thrVP7Arv0YNmbPJESGKi/
GfUG206GipE+PGStykXjZgMfiyUHrrxA1rs8XvlwTpSoeBUtkNYow/h3pAzhSLOd
yjGZIQbOEV/59Bfb1aWI60VIU0tdPOyy0h2feqPbB4ViFnYbHQuTmM9pgCjJwvBE
JZrjTTel9zGhQrB4LoSJoWOxMRDQifGjdCeO20EthwGr+zTTXWBox2q3AquBIRKa
leAgn4ECgYEA7XVnHP8qh7R19qzyOzTN02Us17Xt+xreiySluQREk123+hQxANyZ
bP4JZMKCZoORcFEIhIyCmplgwVCacNGML8TnraTtNW1iz91U9sYv0wHEABBIHnzf
2vTmsx6Uf9B7qsM0jXqn0h2Fti5POsy7sZFdSuP5zbB9FW6aQPIhpN0CgYEAxjkH
rZ/lrvvpwQuHKMlULQNSEQOvTf2uQ4VPlktq1JThijLGoxV6MTKSf/LVU9QsoMeT
12aCjkfwzBzrSwonPY0Zqu7spdTBcM0xkibZ0sKEzy9cgyRz41TuxnIzULoyCvLI
P1njpRVxgsjW2I9rOs6SMS6H1XKBGRAk5Sz3CrkCgYEA4Cz5Js/ip/D/eNz3ZlvI
gO1Ac3lG7cwFExmK9uuHjhRpLsfHJ4gbtGD0H1LeZseJE578yp4YYrmwNXDSDPZX
QXXEPxO3+buGELVklACwf6VoE6NLYrUTTSPVdH7HNQ9u4NyfDX4hV2UVqdN4awuD
mvSgPaaSW9RlkkkziWLNzmUCgYAJbXr1Ag7dhLO4b8Ds6q5rOaY0kvVKg08/fN6t
KkcZdz9G4GVcKlBWeK5JEZad1xCMURGyA/kfpUJJovJ57jCxl71pyNVOidDteYTr
C5f+kyvX4svGnPw6CrcUjyfrpf9tT+DASpkuJ9fvPXgicqfJ8zs2xZzGRRzowUDP
+ZSCWQKBgQCv4zXj8L1bF7eGy12CeusSWNP9wO9B/VPGgVYG/B6xVzRdkTelIMDu
44M1g13K5F9LTD8Mz1rl/+oxXBss1go2tzsXO5Y+vjKlET9ynfZnJflojgaR0QHO
qi2lhK9tNxxLDeOtdzBqTqEK9Sw+EUVEV/l+G8DIJah/0qhIBpx3mA==
-----END RSA PRIVATE KEY-----"""

    created_vault = Vault.create!({
      ref_id: ls.id,
      entity_type: "LocationServer",
      data: private_key

    })

    created_vault.reload

    assert_equal created_vault.data, private_key
    assert_equal created_vault.model.id, ls.id
    assert_equal ls.vault.id, created_vault.id
    assert_equal ls.vault.data, private_key
  end
end
