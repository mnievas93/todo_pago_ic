Contenido:
- Archivo xx_estructura: DDL para generar la BD Operations completa, que es la que tiene las tablas
de seed / parametr�a. La BD Transactions no tiene tablas seeds/param�tricas.
- Archivo xx_datos: informaci�n para popular las tablas seeds / de parametr�a.
- Listado_tablas_seed_parametria: indica cu�les tablas son seed o de parametr�a.

Consideramos:
- Seed: a aquellos datos que se requieren para que la aplicaci�n funcione correctamente y que no
var�an por ambiente. Ej: Moneda, Tipo de Transacci�n, Tipo de Medio de Pago.

- Parametr�a: a aquellos datos que se requieren para que la aplicaci�n funcione pero que var�an por cada ambiente.
Ej: Regla Bonificacion, Limite.