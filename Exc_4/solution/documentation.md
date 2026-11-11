# Solution - Exercise 4

## 1. Start PostgreSQL Docker Container (`postgres:18`)
- Create persistent Docker volume:
  ```sh
  docker volume create pgdata_18
  ```
- Run PostgreSQL container with environment variables and persistent volume mapping:
  ```sh
  docker run -d \
    --name postgres18-db \
    -p 5432:5432 \
    -e POSTGRES_USER=docker \
    -e POSTGRES_PASSWORD=docker \
    -e POSTGRES_DB=order \
    -v pgdata_18:/var/lib/postgresql/18/docker \
    postgres:18
  ```
- Alternatively, using the provided environment file:
  ```sh
  docker run -d \
    --name postgres18-db \
    --network host \
    --env-file debug.env \
    -v pgdata_18:/var/lib/postgresql/18/docker \
    postgres:18
  ```
- Connect database viewer (GoLand / DBeaver / VSCode) via `jdbc:postgresql://localhost:5432/order` (or `app_db`) using the configured credentials.

---

## 2. Prepopulate Database in Code
- Implemented in `skeleton/repository/db.go` inside the `prepopulate(dbConn *gorm.DB) error` function.
- It inserts default drinks (`Beer`, `Wine`, `Cocktail`) and sample orders across different timestamps (`time.Now()`, `-24h`, `-48h`, `-72h`).

---

## 3. Multi-Stage Dockerfile
- Defined in `skeleton/Dockerfile`:
  - **Stage 1 (`builder`)**: Uses `golang:1.27`, sets workdir to `/app`, copies contents, fixes line endings, and executes `./scripts/build-application.sh` to output `/app/ordersystem`.
  - **Stage 2 (`runtime`)**: Uses `alpine:latest`, copies `/app/ordersystem` from the builder stage, exposes port 3000, and sets `ENTRYPOINT ["/app/ordersystem"]`.

---

## 4. Build & Run Orderservice Container
- Build the container image:
  ```sh
  docker build -t orderservice .
  ```
- Run the orderservice container passing the environment file:
  ```sh
  docker run -d \
    --name orderservice \
    --network host \
    --env-file debug.env \
    orderservice
  ```

---

## 5. Scripts to Build, Run Database and Orderservice
- The commands are scripted in `skeleton/run.sh` (POSIX sh) and `skeleton/run.ps1` (PowerShell).
- To run the entire environment at once:
  - On Linux/macOS/Git Bash:
    ```sh
    cd skeleton
    chmod +x run.sh
    ./run.sh
    ```
  - On Windows PowerShell:
    ```powershell
    cd skeleton
    .\run.ps1
    ```

---

## 6. Access Ports & Endpoints
- **Web Frontend**: `http://localhost:3000`
- **Swagger / OpenAPI Documentation**: `http://localhost:3000/openapi/index.html`
- **REST Endpoints**:
  - `GET http://localhost:3000/api/menu`
  - `GET http://localhost:3000/api/order/all`
  - `GET http://localhost:3000/api/order/totalled`
  - `POST http://localhost:3000/api/order`
- **PostgreSQL Database**:
  - Host: `localhost` (or `127.0.0.1`)
  - Port: `5432`
  - Database: `order`
  - User: `docker` / Password: `docker`
