module Heroku::Command
  class Pg < BaseWithApp
    Help.group("heroku-postgresql") do |group|
      group.command "pg:info",   "show database status"
      group.command "pg:wait",   "wait for database to come online"
      group.command "pg:attach", "use heroku-postgresql database as DATABASE_URL"
      group.command "pg:detach", "revert to using shared Postgres database"
      group.command "pg:psql",   "open a psql shell to the database"
    end

    def initialize(*args)
      super
      @config_vars =  heroku.config_vars(app)
      @bifrost_url = ENV["BIFROST_URL"] || @config_vars["BIFROST_URL"]
      @database_url = @config_vars["DATABASE_URL"]
      if !@bifrost_url
        abort("The addon is not installed for the app #{app}")
      end
      uri = URI.parse(@bifrost_url)
      @database_user =     uri.user
      @database_password = uri.password
      @database_host =     uri.host
      @database_name =     uri.path[1..-1]
    end

    def info
      database = bifrost_client.get_database(@database_name)
      display("=== #{app} heroku-postgresql database")
      display("State:          #{database[:state]} for " +
                               "#{delta_format(Time.parse(database[:state_updated_at]))}")
      display("Data size:      #{size_format(database[:num_bytes])} in " +
                              "#{database[:num_tables]} table#{database[:num_tables] == 1 ? "" : "s"}")
      display("URL:            #{@bifrost_url}")
      display("Born:           #{time_format(database[:created_at])}")
    end

    def wait
      ticks = 0
      loop do
        database = bifrost_client.get_database(@database_name)
        state = database[:state]
        if state == "running"
          redisplay("The database is now ready", true)
          break
        elsif state == "destroyed"
          redisplay("The database has been destroyed", true)
          break
        elsif state == "failed"
          redisplay("The database encountered an error", true)
          break
        else
          redisplay("#{state} database #{spinner(ticks)}", false)
        end
        ticks += 1
        sleep 1
      end
    end

    def attach
      if @database_url == @bifrost_url
        display("The database is already attached to app #{app}")
      else
        display("Attatching database to app #{app} ... ", false)
        res = heroku.add_config_vars(app, {"DATABASE_URL" => @bifrost_url})
        display("done")
      end
    end

    def detach
      if @database_url.nil?
        display("A heroku-postgresql database is not attached to app #{app}")
      elsif @database_url != @bifrost_url
        display("Database attached to app #{app} is not a heroku-postgresql database")
      else
        display("Detatching database from app #{app} ... ", false)
        res = heroku.remove_config_var(app, "DATABASE_URL")
        display("done")
      end
    end

    def psql
      bifrost_client.ingress(@database_name)
      ENV["PGPASSWORD"] = @database_password
      cmd = "psql -U #{@database_user} -h #{@database_host} #{@database_name}"
      display("Connecting to database for app #{app} ...")
      system(cmd)
    end

    protected

    def bifrost_client
      ::HerokuPostgresql::Client.new(@database_user, @database_password)
    end

    def spinner(ticks)
      %w(/ - \\ |)[ticks % 4]
    end

    def redisplay(line, line_break = false)
      display("\r\e[0K#{line}", line_break)
    end

    def delta_format(start, finish = Time.now)
      secs = (finish.to_i - start.to_i).abs
      mins = (secs/60).round
      hours = (mins / 60).round
      days = (hours / 24).round
      weeks = (days / 7).round
      months = (weeks / 4.3).round
      years = (months / 12).round
      if years > 0
        "#{years} yr"
      elsif months > 0
        "#{months} mo"
      elsif weeks > 0
        "#{weeks} wk"
      elsif days > 0
        "#{days}d"
      elsif hours > 0
        "#{hours}h"
      elsif mins > 0
        "#{mins}m"
      else
        "#{secs}s"
      end
    end

    KB = 1024
    MB = 1024 * KB
    GB = 1024 * MB

    def size_format(bytes)
      return "#{bytes}B" if bytes < KB
      return "#{(bytes / KB).round}K" if bytes < MB
      return "#{(bytes / MB).round}M" if bytes < GB
      return "#{(bytes / GB).round}G"
    end

    def time_format(time)
      time = Time.parse(time) if time.is_a?(String)
      time.strftime("%Y-%m-%d %H:%M %Z")
    end
  end
end