- Start a PostgreSQL docker container (`postgres:18`) using plain docker commands
    - Use environment variables in db
    - Map the PostgreSQL storage (`/var/lib/postgresql/18/docker`) to a Docker volume to make it persistent
    - Connect a database viewer to the db ([GoLand](https://www.jetbrains.com/help/go/quick-start-with-database-functionality.html), [VSCode](https://marketplace.visualstudio.com/items?itemName=ms-ossdata.vscode-pgsql), [DBeaver](https://dbeaver.io/))

- Solution:
  - docker volume create pgdata_18
  - docker run -d --name postgres18-db -p 5432:5432 -e POSTGRES_USER=... -e POSTGRES_PASSWORD=... -e POSTGRES_DB=app_db -v pgdata_18:/var/lib/postgresql/18/docker postgres:18
  - GoLand initializing with: "jdbc:postgresql://localhost:5432/postgres" user, password
  - 
