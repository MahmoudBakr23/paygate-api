# pg_dump 17+ emits `SET transaction_timeout = 0` which PostgreSQL < 17.4 does
# not recognise. Strip it from structure.sql after every schema dump so the file
# stays loadable on the local PG 14 dev/test server.
Rake::Task["db:schema:dump"].enhance do
  structure = Rails.root.join("db/structure.sql")
  next unless structure.exist?

  content = structure.read.gsub(/^SET transaction_timeout = \d+;\n/, "")
  structure.write(content)
end
