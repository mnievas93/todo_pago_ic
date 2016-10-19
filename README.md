## Descripción
Repositorio para los archivos de configuración utilizados en Integración Continua para el proyecto TodoPago.

El mismo consta de la siguiente estructura:

```sh
RAIZ
 +- dependencies.json (archivo que contiene la dependencia de versiones de cada módulo del proyecto TodoPago)
 +- scripts (directorio que contiene los scripts de despliegue utilizados para desplegar los módulos del proyecto TodoPago)
```

## Motivación
* Mantener controlados y organizados los archivos de configuración utilizados para el despliegue del proyecto TodoPago y cada uno de sus módulos.
* Obtener visibilidad entre la versión del proyecto TodoPago y las versiones correspondientes a cada módulo que lo compone en el despliegue entre ambientes. 

## Lineamientos de Uso

El archivo **dependencies.json** será el que mantenga la correspondencias entre la versión del proyecto TodoPago y la de cada uno de sus módulos. 

El formato del archivo es el siguiente:

```
{
	"TodoPago": {
		"version": "x.y",
		"dependencies": {
			"ESB-ModuloUno": {
				"version_tag": "<identificador del tag>"
			},
			"ESB-ModuloDos": {
				"version_tag": "<identificador del tag>"
			}
			
			...
			
			"Notificaciones": {
				"version_tag": "<identificador del tag>"
			},
			"Panel": {
				"version_tag": "<identificador del tag>"
			},
			"Portal": {
				"version_tag": "<identificador del tag>"
			}
		}
	}
}
```

* versión: Es el número de versión del proyecto TodoPago a desplegar (debe corresponderse con un tag de la forma **vx.y** en este repositorio)
* dependencies: Por cáda uno de los módulos que conforman el proyecto, debe agregarse una entrada en las dependencias bajo la siguiente convención:
    * Nombre del Módulo: Identificador en formato **CamelCase** de un módulo del proyecto TodoPago. Para los módulos del ESB se utilizará el prefijo **ESB-**, por ejemplo ESB-DataService o ESB-BilleteraCuenta de manera equivalente a los nombres de los JOBs definidos en Jenkins.
    * version_tag: Identificador del tag en el repositorio de código del módulo correspondiente. Debe definir la versión del mismo. **TBD: Explicar convención utiliada para los tags**

## Forma de trabajo para el desarrollador

**TBD: hasta donde, definimos acá lo que tiene que hacer en su operatoria (generar el archivo cuando vaya a pasar entre ambientes), correr el job en jenkins, etc?. Agregamos aca el procedimiento ante el alta de un nuevo módulo que implica una corrrespondencia con jenkins?**

