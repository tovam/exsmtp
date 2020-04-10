defmodule Exsmtp.Handler do
  @behaviour :gen_smtp_server_session
  require Logger

  # SMTP codes
  @smtp_too_busy 421
  @smtp_requested_action_okay 250
  @smtp_mail_action_abort 552
  @smtp_unrecognized_command 500

  defmodule State do
    defstruct options: []
  end

  def init(hostname, _session_count, _client_ip_address, options) do
    banner = [hostname, " Exsmtp server"]
    state  = %State{options: options}
    {:ok, banner, state}
  end

  def handle_HELO(hostname, state) do
    Logger.debug(" EXSMTP/handle_HELO")
    Logger.debug("#{@smtp_requested_action_okay} HELO from #{hostname}")
    {:ok, 655360, state}
  end

  def handle_EHLO(_hostname, extensions, state) do
    Logger.debug(" EXSMTP/handle_EHLO")
    {:ok, extensions, state}
  end

  def handle_MAIL(_sender, state) do
    Logger.debug(" EXSMTP/handle_MAIL")
    {:ok, state}
  end

  def handle_RCPT(_to, state) do
    Logger.debug(" EXSMTP/handle_RCPT")
    {:ok, state}
  end

  def handle_VRFY(_address, state) do
    Logger.debug(" EXSMTP/handle_VRFY")
    {:error, "252 VRFY disabled by policy, no peeking", state}
  end

  def handle_DATA(_from, _to, "", state) do
    Logger.debug(" EXSMTP/handle_DATA")
    {:error, "#{@smtp_mail_action_abort} Message too small", state}
  end

  def handle_DATA(from, to, data, state) do
    Logger.debug(" EXSMTP/handle_DATA")
    unique_id = UUID.uuid4()
    Logger.debug("Message from #{from} to #{to} with body length #{byte_size(data)} queued as #{unique_id}")
    mail = parse_mail(data, state, unique_id)
    Logger.info("#{inspect mail}")
    {:ok, unique_id, state}
  end

  def handle_MAIL_extension(extension, _state) do
    Logger.debug(" EXSMTP/handle_MAIL_extension")
    {:error, "Unknown MAIL FROM #{extension}"}
  end

  def handle_RCPT_extension(extension, _state) do
    Logger.debug(" EXSMTP/handle_RCPT_extension")
    {:error, "Unknown RCPT TO extension #{extension}"}
  end

  def handle_RSET(state) do
    Logger.debug(" EXSMTP/handle_RSET")
    state
  end

  def handle_other(verb, _args, state) do
    Logger.debug(" EXSMTP/handle_other")
    {["#{@smtp_unrecognized_command} Error: command not recognized : '", verb, "'"], state}
  end

  def terminate(reason, state) do
    {:ok, reason, state}
  end

  def code_change(_oldversion, state, _extra) do
    {:ok, state}
  end

  defp parse_mail(data, _state, _unique_id) do
    Logger.debug(" EXSMTP/parse_mail")
    try do
      :mimemail.decode(data)
    rescue
      reason ->
        IO.puts("Message decode FAILED with #{reason}")
    end
  end
end
