use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Config {
    pub server: ServerConfig,
    pub database: DatabaseConfig,
}

#[derive(Debug, Deserialize)]
pub struct ServerConfig {
    pub port: u16,
    #[serde(default)]
    pub password: String,
}

#[derive(Debug, Deserialize)]
pub struct DatabaseConfig {
    pub host: String,
    pub port: u16,
    pub user: String,
    pub password: String,
    pub name: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            server: ServerConfig {
                port: 7378,
                password: String::new(),
            },
            database: DatabaseConfig {
                host: "127.0.0.1".to_string(),
                port: 3306,
                user: "tally_user".to_string(),
                password: "tally_password".to_string(),
                name: "tally".to_string(),
            },
        }
    }
}

impl Config {
    pub fn load() -> Self {
        let config_path =
            std::env::var("CONFIG_PATH").unwrap_or_else(|_| "config.toml".to_string());

        let mut config = match std::fs::read_to_string(&config_path) {
            Ok(content) => match toml::from_str(&content) {
                Ok(parsed) => {
                    println!("[debug] loaded cfg from {}", config_path);
                    parsed
                }
                Err(err) => {
                    eprintln!(
                        "[debug] failed to parse config file {}: {}. falling back to defaults",
                        config_path, err
                    );
                    Config::default()
                }
            },
            Err(err) => {
                eprintln!(
                    "[debug] config file {} not found: {}. falling back to environment/defaults",
                    config_path, err
                );
                Config::default()
            }
        };

        config.server.port = std::env::var("PORT")
            .ok()
            .and_then(|value| value.parse().ok())
            .unwrap_or(config.server.port);

        if let Ok(password) = std::env::var("API_PASSWORD") {
            config.server.password = password;
        }

        config.database.host = std::env::var("DB_HOST").unwrap_or(config.database.host);
        config.database.port = std::env::var("DB_PORT")
            .ok()
            .and_then(|value| value.parse().ok())
            .unwrap_or(config.database.port);
        config.database.user = std::env::var("DB_USER").unwrap_or(config.database.user);
        config.database.password = std::env::var("DB_PASSWORD").unwrap_or(config.database.password);
        config.database.name = std::env::var("DB_NAME").unwrap_or(config.database.name);

        println!(
            "[debug] final config: server_port={}, api_auth={}, db_host={}, db_port={}, db_user={}, db_name={}",
            config.server.port,
            if config.server.password.is_empty() {
                "disabled"
            } else {
                "enabled"
            },
            config.database.host,
            config.database.port,
            config.database.user,
            config.database.name,
        );

        config
    }

    pub fn database_url(&self) -> String {
        format!(
            "mysql://{}:{}@{}:{}/{}",
            self.database.user,
            self.database.password,
            self.database.host,
            self.database.port,
            self.database.name,
        )
    }
}
