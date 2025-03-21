# KrakenStreamer

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Docker Deployment

To run the application using Docker:

1. Generate a new secret key base:
   ```bash
   mix phx.gen.secret
   ```

2. Update the "SECRET_KEY_BASE" in docker-compose.yml with generated key.

3. Build and start the application:
   ```bash
   docker-compose up --build
   ```

The application will be available at http://localhost:8080

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
