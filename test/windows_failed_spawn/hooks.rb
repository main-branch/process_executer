# frozen_string_literal: true

# Instrumentation for the hand-run scripts in this directory. Nothing here is in the gem.
#
# It lets a script turn the chdir: check off, so that a missing directory reaches
# Process.spawn as a directory removed after the check would, and it counts how often
# StandardStreamGuard restored stdout and stderr.
require 'process_executer'
$guard_restores = 0
module SkipChdirCheck
  def check_chdir = (super unless ENV['PE_SKIP_CHDIR_CHECK'] == '1')
end

module CountRestores
  def restore(copies)
    super
    $guard_restores += 1
  rescue SystemCallError, IOError => e
    File.write("restore-error-#{Process.pid}.txt", RestoreError.describe(e, copies))
    raise
  end
end

# What the copies and the streams looked like when a restore raised
module RestoreError
  def self.describe(error, copies)
    lines = ["#{error.class}: #{error.message}", "restart depth=#{caller.count { |frame| frame.include?('repair_and_release') }}"]
    copies.each { |fd, copy| lines << "copy of #{fd}: #{state(copy)} | other open IO objects on that descriptor: #{sharing(copy)}" }
    { 1 => STDOUT, 2 => STDERR }.each { |fd, io| lines << "stream #{fd}: #{state(io)}" }
    lines.join("\n")
  end

  def self.state(io)
    "closed?=#{io.closed?} fileno=#{io.fileno} type=#{io.stat.ftype}"
  rescue SystemCallError, IOError => e
    "#{e.class}: #{e.message}"
  end

  def self.sharing(io)
    number = io.fileno
    ObjectSpace.each_object(IO).select { |other| !other.equal?(io) && !other.closed? && other.fileno == number }.map(&:inspect)
  rescue SystemCallError, IOError => e
    "#{e.class}: #{e.message}"
  end
end
ProcessExecuter::Commands::SpawnWithTimeout.prepend(SkipChdirCheck)
ProcessExecuter::Commands::StandardStreamGuard.prepend(CountRestores)
