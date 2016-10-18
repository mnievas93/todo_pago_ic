Contenido:
- Archivo xx_estructura: DDL para generar la BD Operations completa, que es la que tiene las tablas
de seed / parametría. La BD Transactions no tiene tablas seeds/paramétricas.
- Archivo xx_datos: información para popular las tablas seeds / de parametría.
- Listado_tablas_seed_parametria: indica cuáles tablas son seed o de parametría.

Consideramos:
- Seed: a aquellos datos que se requieren para que la aplicación funcione correctamente y que no
varían por ambiente. Ej: Moneda, Tipo de Transacción, Tipo de Medio de Pago.

- Parametría: a aquellos datos que se requieren para que la aplicación funcione pero que varían por cada ambiente.
Ej: Regla Bonificacion, Limite.