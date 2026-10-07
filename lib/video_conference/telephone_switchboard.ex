defmodule VideoConference.TelephoneSwitchboard do
  alias VideoConference.TelephoneSwitchboard.PhoneCalls
  alias VideoConference.TelephoneSwitchboard.SharedLinks

  def connection_credentials(
        from_host_id: from_host_id,
        from: from,
        to_host_id: to_host_id,
        to: to,
        direction: direction,
        stream_types: stream_types
      ) do
    PhoneCalls.connection_credentials(
      from_host_id: from_host_id,
      from: from,
      to_host_id: to_host_id,
      to: to,
      direction: direction,
      stream_types: stream_types
    )
  end

  def connection_credentials(
        shared_link_id: link_id,
        password: password,
        stream_types: stream_types
      ) do
    SharedLinks.connection_credentials(
      link_id: link_id,
      password: password,
      stream_types: stream_types
    )
  end

  def connection_credentials(shared_link_id: link_id, stream_types: stream_types) do
    SharedLinks.connection_credentials(link_id: link_id, stream_types: stream_types)
  end

  def current_income_calls(to: to) do
    PhoneCalls.current_income_calls(to: to)
  end

  def shared_link_by(link_id: link_id) do
    SharedLinks.one_by(link_id: link_id)
  end
end
