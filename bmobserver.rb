require 'sinatra'
require 'json'
require 'sqlite3'

class BmobServer < Sinatra::Base
  not_found do
    status 404
    "<h1>404</h1>"
  end

  get "/" do
    db = SQLite3::Database.new("./mobs.db")
    @counts = []
    db.execute("SELECT contributor, count(contributor) FROM bmobs GROUP BY contributor ORDER BY count(contributor)") do |row|
      @counts << row
    end
    @counts = @counts.sort_by { |(who, count)| count }.reverse
    @total = @counts.inject(0) { |cur, (who, count)| cur + count }
    db.close()

    haml :"counts.html"
  end

  post "/upload" do
    entries = JSON.parse(request.body.read)
    db = SQLite3::Database.new("./mobs.db")
    
    count = 0
    dupes = 0
    db.execute("BEGIN")
    entries.each do |e|
      e["count"] ||= 1
      begin
        count += 1
        updated = false
        db.execute("SELECT * FROM bmobs WHERE id = ?", e["id"]) do
          updated = true
          # just replace it
          db.execute("UPDATE bmobs
                      SET keywords = ?, date = ?, count = ?
                      WHERE id = ?", e["keywords"], e["date"], e["count"], e["id"])
        end
        next if updated

        db.execute("INSERT INTO bmobs (id, name, locuid, keywords, date, contributor, count)
                    VALUES (?, ?, ?, ?, ?, ?, ?)", 
                    e["id"], e["name"], e["locuid"], e["keywords"], e["date"], e["contributor"], e["count"])

      rescue SQLite3::ConstraintException => e
        dupes += 1
        # Ignore duplicate entry.
      end
    end
    db.execute("END")
    db.close

    content_type :"text/plain"
    "Uploaded #{count}, #{dupes} were duplicates."
  end

  get "/download/:date" do
    content_type :"text/json"
    db = SQLite3::Database.new("./mobs.db")

    entries = {entries: []}
    db.execute("SELECT * FROM bmobs WHERE date > ?", params[:date]) do |row|
      id, name, locuid, keywords, date, contributor, count = row
      entries[:entries] << {
        id: id, name: name, locuid: locuid,
        keywords: keywords, date: date, contributor: contributor,
        count: count
      }
      

    end
    db.close

    JSON.dump(entries)

  end

  get "/mobs.db" do
    send_file("./mobs.db")
  end

end
