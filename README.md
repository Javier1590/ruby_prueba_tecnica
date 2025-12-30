EasyBroker API Challenge (Ruby)
Este proyecto implementa un cliente en Ruby que consume la API de EasyBroker para obtener los títulos de propiedades.
Incluye:
Cliente HTTP con manejo de paginación
Reintentos automáticos con backoff exponencial para errores transitorios (429, 5xx)
Pruebas unitarias con Minitest
Código orientado a buenas prácticas de OOP y diseño limpio
Requisitos
Ruby 2.7+ o 3.x
No se requieren gems externas (solo librería estándar).
Define la variable de entorno:
Windows (PowerShell)
setx EASYBROKER_API_KEY "Tu llave API aca"
macOS / Linux
export EASYBROKER_API_KEY="Tu llave API aca"
Uso
Para ejecutar el cliente contra el ambiente de pruebas de EasyBroker y mostrar los títulos de todas las propiedades:
ruby -e "require './easy_broker_client'; client = EasyBrokerClient.new(api_key: ENV['EASYBROKER_API_KEY']); client.print_titles"
Estructura del proyecto

.
├── easy_broker_client.rb     # Cliente principal de la API
├── test_easy_broker_client.rb# Pruebas unitarias (Minitest)
└── README.md

Diseño y decisiones técnicas
Cliente (EasyBrokerClient)
Implementa una responsabilidad única: consumir la API de EasyBroker.
Maneja automáticamente:
Paginación (page, limit)
Errores HTTP
Reintentos con backoff exponencial
Permite inyección de dependencias:
Cliente HTTP
Función sleep
Esto facilita pruebas rápidas, deterministas y sin dependencias externas.
Reintentos
Códigos soportados:
429 Too Many Requests
5xx Server Errors
Backoff exponencial configurable.
Excepción clara cuando se agotan los reintentos.
Pruebas unitarias
Implementadas con Minitest
Incluyen escenarios de:
Paginación múltiple
Reintentos por 429
Agotamiento de reintentos
Respuesta JSON inválida
No realizan llamadas reales a la API (uso de stubs).
Ejecutar pruebas
Desde la carpeta del proyecto:
ruby test_easy_broker_client.rb
Salida esperada:
5 runs, 10 assertions, 0 failures, 0 errors
Seguridad
Se utiliza ENV['EASYBROKER_API_KEY'] como buena práctica estándar.

Posibles mejoras
Soporte opcional para Faraday
Logging estructurado
Empaquetar como gema Ruby
Manejo completo de Retry-After con formato de fecha HTTP
Autor
Implementado como parte del API Challenge de EasyBroker
con enfoque en claridad, mantenibilidad y buenas prácticas Ruby.