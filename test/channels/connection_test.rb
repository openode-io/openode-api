class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test 'connects with header token' do
    user = User.first
    connect headers: { token: user.token }

    assert_equal connection.current_user.id, user.id
  end

  test 'connects with param token' do
    user = User.first
    connect params: { token: user.token }

    assert_equal connection.current_user.id, user.id
  end

  test 'rejects connection without header' do
    assert_reject_connection { connect }
  end
end
