USE [Configurations]
GO
/****** Object:  StoredProcedure [dbo].[Actualizar_Cargos_Por_Transaccion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Actualizar_Cargos_Por_Transaccion] (  
 @fecha_alta DATETIME = NULL,  
 @id_transaccion VARCHAR(36),  
 @monto_calculado DECIMAL(12,2),  
 @valor_aplicado DECIMAL(12,2),  
 @id_cargo INT,  
 @id_tipo_aplicacion INT,  
 @usuario_alta VARCHAR(20) = NULL  
 )              
AS  
  
DECLARE @msg VARCHAR(255) = NULL;  
  
SET NOCOUNT ON;  
  
BEGIN TRANSACTION;  
  
BEGIN TRY  
 IF(@id_transaccion IS NULL)  
  THROW 51000, 'id_transaccion Nulo', 1;  
  
 IF(@monto_calculado IS NULL)  
  THROW 51000, 'monto_calculado Nulo', 1;  
  
 IF(@valor_aplicado IS NULL)  
  THROW 51000, 'valor_aplicado Nulo', 1;  
  
 IF(@id_cargo IS NULL)  
  THROW 51000, 'id_cargo Nulo', 1;  
  
  
 INSERT INTO [dbo].[Cargos_Por_Transaccion] (  
  [fecha_alta],  
  [id_transaccion],  
  [monto_calculado],  
  [valor_aplicado],  
  [id_cargo],  
  [id_tipo_aplicacion],  
  [usuario_alta]  
 ) VALUES (  
  @fecha_alta,  
  @id_transaccion,  
  @monto_calculado,  
  @valor_aplicado,  
  @id_cargo,  
  @id_tipo_aplicacion,  
  @usuario_alta  
 );  
END TRY  
BEGIN CATCH  
 ROLLBACK TRANSACTION;  
 SELECT @msg  = ERROR_MESSAGE();  
 THROW  51000, @msg, 1;  
END CATCH;  
  
COMMIT TRANSACTION;  
  
RETURN 1;  
GO
/****** Object:  StoredProcedure [dbo].[Actualizar_Cuenta_Virtual]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Actualizar_Cuenta_Virtual] ( 
             @monto_disponible decimal (12,2) = NULL,
             @validacion_disponible decimal (12,2) = NULL,
             @monto_saldo_en_cuenta decimal (12,2) = NULL,
             @validacion_saldo_en_cuenta decimal (12,2) = NULL,
             @monto_saldo_en_revision decimal (12,2) = NULL,
             @validacion_saldo_en_revision decimal (12,2) = NULL,
             @id_cuenta int,
             @usuario_alta varchar (20) = NULL,
             @id_tipo_movimiento int,
             @id_tipo_origen_movimiento int,
             @id_log_proceso int = NULL
)            
AS 
DECLARE @RetCode    INT          
             
SET NOCOUNT ON;

--Ver como se comporta el sp con carga y concurrencia.
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE

declare @recupero_disponible decimal (12,2)
declare @recupero_saldo_cuenta decimal (12,2)
declare @recupero_saldo_revison decimal (12,2)
declare @nuevo_disponible decimal (12,2)
declare @nuevo_saldo_en_cuenta decimal (12,2)
declare @nuevo_saldo_en_revision decimal (12,2)
DECLARE @Msg        VARCHAR(255)

BEGIN TRANSACTION

BEGIN TRY

-- Valido parametros ingresados. Deben existir para poder realizar la operacion.
--@id_cuenta
IF (@id_cuenta IS NULL)
	BEGIN
             SELECT  @RetCode = 401
             ;THROW 51000, 'Id Cuenta Nulo', 1;
	END
--@id_tipo_movimiento 
IF (@id_tipo_movimiento IS NULL)
	BEGIN
             SELECT  @RetCode = 402
             ;THROW 51000, 'Id Tipo Movimiento Nulo', 1;
	END
--@id_tipo_origen_movimiento 
IF (@id_tipo_origen_movimiento IS NULL)
	BEGIN
             SELECT  @RetCode = 403
             ;THROW 51000, 'Id Tipo Origen Movimiento Nulo', 1;
	END

-- Al menos uno de estos parametros no debe ser nulo.
--@id_log_proceso
--@usuario_alta
IF (@id_log_proceso IS NULL 
	AND @usuario_alta IS NULL)
	BEGIN
             SELECT  @RetCode = 404
             ;THROW 51000, 'Debe informarse el parametro id_log_proceso o usuario_alta', 1;
	END

-- Al menos uno de estos parametros no debe ser nulo.
--@monto_disponible
--@monto_saldo_en_cuenta
--@monto_saldo_en_revision
IF (@monto_disponible IS NULL 
	AND @monto_saldo_en_cuenta IS NULL
	AND @monto_saldo_en_revision IS NULL)
	BEGIN
             SELECT  @RetCode = 405
             ;THROW 51000, 'Alguno de los montos debe ser distinto de nulo.', 1;
	END

-- Verifico que la cuenta exista. Si no existe salgo por 
IF (NOT EXISTS (SELECT 1 FROM Cuenta_Virtual WHERE id_cuenta = @id_cuenta))
	BEGIN
             SELECT  @RetCode = 400
             ;THROW 51000, 'Cuenta Inexistente', 1;
	END

-- Recupero disponibles actuales para realizar las validaciones correspondientes.
-- Ver si aca es necesario realizar la lectura con un hint de updlock, ya que la informacion se actualizara.
SELECT  @recupero_disponible = disponible,
        @recupero_saldo_cuenta = saldo_en_cuenta,
        @recupero_saldo_revison = saldo_en_revision
FROM    Cuenta_Virtual 
WHERE   id_cuenta = @id_cuenta;

--Realizar las sumas una sola vez
SET @nuevo_disponible = @recupero_disponible + ISNULL(@monto_disponible, 0);
SET @nuevo_saldo_en_cuenta = @recupero_saldo_cuenta + ISNULL(@monto_saldo_en_cuenta,0);
SET @nuevo_saldo_en_revision = @recupero_saldo_revison + ISNULL(@monto_saldo_en_revision, 0);

-- Asumo que la version de SQL trabaja con short circuit, por esto pregunto primero si la validacion es distinto de nulo y luego por el calculo de la validacion
IF (@validacion_disponible IS NOT NULL) AND (@nuevo_disponible < @validacion_disponible)
    BEGIN
             SELECT  @RetCode = 100
             ;THROW 51000, 'Disponible Insuficiente', 1;
    END 

-- Asumo que la version de SQL trabaja con short circuit, por esto pregunto primero si la validacion es distinto de nulo y luego por el calculo de la validacion
IF (@validacion_saldo_en_cuenta IS NOT NULL) AND (@nuevo_saldo_en_cuenta < @validacion_saldo_en_cuenta)
    BEGIN
             SELECT  @RetCode = 200
             ;THROW 51000, 'Saldo En Cuenta Insuficiente', 1;
    END 

-- Asumo que la version de SQL trabaja con short circuit, por esto pregunto primero si la validacion es distinto de nulo y luego por el calculo de la validacion
IF (@validacion_saldo_en_revision IS NOT NULL) AND (@nuevo_saldo_en_revision < @validacion_saldo_en_revision)
    BEGIN
             SELECT  @RetCode = 300
             ;THROW 51000, 'Saldo En Revision Insuficiente', 1;
    END 

--Ojo aca verificar como se deben actualizar estos disponibles.
UPDATE  Cuenta_Virtual
SET     disponible = disponible + ISNULL(@monto_disponible, 0) ,
        saldo_en_cuenta = saldo_en_cuenta + ISNULL(@monto_saldo_en_cuenta,0) ,
        saldo_en_revision = saldo_en_revision + ISNULL(@monto_saldo_en_revision, 0) 
WHERE id_cuenta = @id_cuenta;

--Debo loguear en la tabla esta actualizacion.
INSERT INTO [dbo].[Log_Movimiento_Cuenta_Virtual]
           ([id_tipo_movimiento]
           ,[id_tipo_origen_movimiento]
           ,[id_log_proceso]
           ,[id_cuenta]
           ,[monto_disponible]
           ,[disponible_anterior]
           ,[disponible_actual]
           ,[saldo_cuenta_anterior]
           ,[saldo_cuenta_actual]
           ,[saldo_revision_anterior]
           ,[saldo_revision_actual]
           ,[fecha_alta]
           ,[usuario_alta]
           ,[fecha_modificacion]
           ,[usuario_modificacion]
           ,[fecha_baja]
           ,[usuario_baja]
           ,[version]
           ,[monto_saldo_cuenta]
           ,[monto_revision])
     VALUES
           (@id_tipo_movimiento
           ,@id_tipo_origen_movimiento
           ,@id_log_proceso
           ,@id_cuenta
           ,@monto_disponible
           ,@recupero_disponible
           ,@nuevo_disponible
           ,@recupero_saldo_cuenta
           ,@nuevo_saldo_en_cuenta
           ,@recupero_saldo_revison
           ,@nuevo_saldo_en_revision
           ,GETDATE()
           ,@usuario_alta
           ,NULL
           ,NULL
           ,NULL
           ,NULL
           ,0
           ,@monto_saldo_en_cuenta
           ,@monto_saldo_en_revision);

END TRY
BEGIN CATCH
       ROLLBACK TRANSACTION 
       SELECT @Msg  = ERROR_MESSAGE()
       ;THROW  51000, @Msg , 1;
END CATCH

COMMIT TRANSACTION 

RETURN 1
GO
/****** Object:  StoredProcedure [dbo].[Actualizar_Cuenta_Virtual_Control]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Actualizar_Cuenta_Virtual_Control] (
	@importe DECIMAL(12, 2) = NULL,
	@id_cuenta INT,
	@fecha_finProceso DATETIME = NULL,
	@usuario_alta VARCHAR(20) = NULL,
	@id_log_proceso INT = NULL
	)
AS
DECLARE @RetCode INT = 0
DECLARE @RetCode_CV INT
DECLARE @disponible_anterior DECIMAL(12, 2)
DECLARE @disponible_actual DECIMAL(12, 2)
DECLARE @disponible_anteriorMASmonto_disponible DECIMAL(12, 2)
DECLARE @v_maximoIDProceso INT
DECLARE @v_id_control INT
DECLARE @v_fecha_actual DATETIME
DECLARE @v_id_tipo_movimiento INT
DECLARE @v_id_origen_movimiento INT
DECLARE @v_id_origen_mov_recupero INT
DECLARE @v_error_msg VARCHAR(255)
DECLARE @Msg VARCHAR(255)

BEGIN
	SET NOCOUNT ON;

	BEGIN TRANSACTION

	BEGIN TRY
		IF (
				@id_cuenta IS NULL
				OR @id_cuenta = 0
				OR @id_log_proceso IS NULL
				OR @usuario_alta IS NULL
				) THROW 51000,
			'Se han recibido valores nulos o cero para variables Cuenta, Proceso o Usuario',
			1;
			IF (@importe IS NULL) THROW 51000,
				'Se ha recibido un valor nulo correspondiente al importe',
				1;
				--Se obtiene el disponible actual de la tabla cuenta virtual                                      
				SELECT @disponible_anterior = Disponible
				FROM configurations.dbo.cuenta_virtual
				WHERE fecha_alta = (
						SELECT MAX(fecha_alta)
						FROM configurations.dbo.cuenta_virtual
						WHERE id_cuenta = @id_cuenta
						)
					AND id_cuenta = @id_cuenta

		--Se sumariza calculando el monto a impactar                                      
		SET @disponible_anteriorMASmonto_disponible = @importe + ISNULL(@disponible_anterior, 0);

		--Se obtiene el tipo y el origen del movimiento                                      
		--Datos necesario para llamar a SP actualizar cuenta virtual                                      
		SELECT @v_id_tipo_movimiento = id_tipo
		FROM configurations.dbo.Tipo tpo
		WHERE tpo.codigo = 'MOV_CRED'
			AND tpo.id_grupo_tipo = 16

		SELECT @v_id_origen_movimiento = id_tipo
		FROM configurations.dbo.Tipo tpo
		WHERE tpo.codigo = 'ORIG_PROCESO'
			AND tpo.id_grupo_tipo = 17

		--Se ejecuta el SP actualizar cuentas virtual                                      
		EXECUTE @RetCode_CV = Configurations.dbo.Actualizar_Cuenta_Virtual @importe --importe a impactar cuenta virtual                                 
			,
			NULL --validacion de disponible                                      
			,
			NULL --monto saldo en cuenta                                      
			,
			NULL --validacion de monto saldo en cuenta                                      
			,
			NULL --monto saldo en revision                                      
			,
			NULL --validacion monto saldo en revision                                      
			,
			@id_cuenta --cuenta a ser modificada                                      
			,
			@usuario_alta --usuario                                      
			,
			@v_id_tipo_movimiento --tipo movimiento                                      
			,
			@v_id_origen_movimiento --origen del movimiento                                      
			,
			@id_log_proceso --id log de proceso                                      

		IF (@RetCode_CV <> 1) THROW 51000,
			'El proceso actualizacion de saldo disponible finalizado con fallas',
			1;
			--Se obtiene nuevamente el saldo disponible                                      
			--Este valor ya ha sido modificado en la tabla cuenta virtual                                      
			SELECT @disponible_actual = Disponible
			FROM configurations.dbo.cuenta_virtual
			WHERE fecha_alta = (
					SELECT MAX(fecha_alta)
					FROM configurations.dbo.cuenta_virtual
					WHERE id_cuenta = @id_cuenta
					)
				AND id_cuenta = @id_cuenta

		--Se obtiene el id de proceso, que corresponde al maximo registro de la tabla log movimiento cuenta virtual                                      
		SELECT @v_maximoIDProceso = lmcv.id_log_proceso,
			@v_id_origen_mov_recupero = lmcv.id_tipo_origen_movimiento
		FROM configurations.dbo.Log_Movimiento_Cuenta_Virtual lmcv
		WHERE fecha_alta = (
				SELECT MAX(fecha_alta)
				FROM configurations.dbo.Log_Movimiento_Cuenta_Virtual cv
				WHERE cv.id_cuenta = @id_cuenta
				)
			AND lmcv.id_cuenta = @id_cuenta

		--Si los saldos no coinciden, pero a su vez el ultimo registro corresponde a actualizacion de saldos, significa que se produjo un error.                                      
		--Se recuperan los valores para insertar dicho registros en tabla Control_Cuenta_Virtual                                      
		IF (
				@disponible_actual <> @disponible_anteriorMASmonto_disponible
				AND @v_maximoIDProceso = @id_log_proceso
				AND @v_id_origen_mov_recupero = 61
				AND @RetCode_CV = 1
				)
		BEGIN
			SELECT @v_id_control = ISNULL(MAX(id_control), 0) + 1
			FROM Configurations.dbo.Control_Cuenta_Virtual

			INSERT INTO Configurations.dbo.Control_Cuenta_Virtual (
				[id_control],
				[id_cuenta],
				[id_log_proceso],
				[disponible_anterior],
				[monto_disponible],
				[disponible_anteriorMASmonto_disponible],
				[disponible_actual],
				[fecha_alta],
				[usuario_alta]
				)
			VALUES (
				@v_id_control,
				@id_cuenta,
				@id_log_proceso,
				@disponible_anterior,
				@importe,
				@disponible_anteriorMASmonto_disponible,
				@disponible_actual,
				getdate(),
				@usuario_alta
				);
		END

		--Actualizar las Transacciones.                                      
		UPDATE Transactions.dbo.transactions
		SET AvailableTimestamp = getdate(),
			AvailableStatus = - 1,
			SyncStatus = 0,
			TransactionStatus = 'TX_DISPONIBLE'
		WHERE id IN (
				SELECT tx.id
				FROM Transactions.dbo.transactions tx
				WHERE LTRIM(RTRIM(tx.OperationName)) IN (
						'Compra_offline',
						'Compra_online'
						)
					AND tx.LiquidationTimestamp IS NOT NULL
					AND tx.liquidationstatus = - 1
					AND tx.AvailableTimestamp IS NULL
					AND (
						tx.availablestatus <> - 1
						OR tx.availablestatus IS NULL
						)
					AND tx.cashouttimestamp <= @fecha_finProceso
					AND tx.TransactionStatus = 'TX_APROBADA'
					AND tx.LocationIdentification = @id_cuenta
				
				UNION ALL
				
				SELECT tx.id
				FROM Transactions.dbo.transactions tx
				WHERE LTRIM(RTRIM(tx.OperationName)) = 'Devolucion'
					AND tx.LiquidationTimestamp IS NOT NULL
					AND tx.liquidationstatus = - 1
					AND tx.AvailableTimestamp IS NULL
					AND (
						tx.availablestatus <> - 1
						OR tx.availablestatus IS NULL
						)
					AND tx.cashouttimestamp <= @fecha_finProceso
					AND tx.TransactionStatus = 'TX_APROBADA'
					AND tx.LocationIdentification = @id_cuenta
				)

		SET @RetCode = 1

		COMMIT TRANSACTION
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0)
			ROLLBACK TRANSACTION;
	END CATCH

	--SET @Fecha_Actual = GETDATE();                                  
	RETURN @RetCode;
END;

GO
/****** Object:  StoredProcedure [dbo].[Actualizar_Cupones]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Actualizar_Cupones] (
	@idTransaccion CHAR(36),
	@id_log_paso_padre INT,
	@usuario VARCHAR(20),
	@id_movimiento_presentado INT,
	@codigo_tipo VARCHAR(15)
	)
AS
DECLARE @id_paso INT = 0;
DECLARE @flag_aceptada_marca BIT;
DECLARE @flag_conciliada BIT;
DECLARE @flag_distribuida BIT;
DECLARE @flag_contracargo BIT;
DECLARE @flag_notificado BIT;
DECLARE @Estado VARCHAR(20);
DECLARE @fecha_pago DATETIME;
DECLARE @importe DECIMAL(12, 2);
DECLARE @moneda INT;
DECLARE @cantidad_cuotas INT;
DECLARE @nro_tarjeta VARCHAR(50);
DECLARE @fecha_movimiento DATETIME;
DECLARE @nro_autorizacion VARCHAR(50);
DECLARE @nro_cupon VARCHAR(50);
DECLARE @cargos_marca_por_movimiento DECIMAL(12, 2);
DECLARE @signo_cargos_marca_por_movimiento VARCHAR(1);
DECLARE @nro_agrupador_boton VARCHAR(50);
DECLARE @ID_PASO_PROCESO INT;
DECLARE @id_conciliacion INT;
DECLARE @id_disputa BIT = NULL;
DECLARE @id_conciliacion_manual INT;
DECLARE @msg VARCHAR(255) = NULL;
DECLARE @FeeAmount DECIMAL(12, 2);
DECLARE @TaxAmount DECIMAL(12, 2);
DECLARE @productidentification INT;
DECLARE @codigo_operacion VARCHAR(5);

SET NOCOUNT ON;

BEGIN TRANSACTION;

BEGIN TRY
	SELECT @Estado = CouponStatus,
		@FeeAmount = FeeAmount,
		@TaxAmount = TaxAmount,
		@productidentification = Productidentification 
	FROM Transactions.dbo.transactions
	WHERE Id = @idTransaccion;

	SELECT @fecha_pago = mpm.fecha_pago, 
	       @codigo_operacion = co.codigo_operacion
	FROM Configurations.dbo.Movimiento_Presentado_MP mpm
	INNER JOIN Configurations.dbo.Codigo_operacion co ON mpm.id_codigo_operacion = co.id_codigo_operacion
	WHERE mpm.id_movimiento_mp = @id_movimiento_presentado;

	IF (@codigo_tipo = 'EFECTIVO')
	BEGIN
		UPDATE Transactions.dbo.transactions
		SET PaymentTimestamp = @fecha_pago,
			ReconciliationStatus = 1,
			ReconciliationTimestamp = GETDATE(),
			SyncStatus = 0,
			CouponStatus = 'ACREDITADO',
			TransactionStatus = 'TX_PROCESADA'
		WHERE Id = @idTransaccion;
	END
	ELSE
	BEGIN
		UPDATE Transactions.dbo.transactions
		SET PaymentTimestamp = @fecha_pago,
			ReconciliationStatus = 1,
			ReconciliationTimestamp = GETDATE(),
			SyncStatus = 0
		WHERE Id = @idTransaccion;

		SET @id_disputa = 0;
	END

	SET @flag_aceptada_marca = 1;
	SET @flag_conciliada = 1;

	SELECT @id_paso = ID_PASO_PROCESO
	FROM Configurations.dbo.LOG_PASO_PROCESO
	WHERE ID_LOG_PASO = @id_log_paso_padre;

	IF (@id_paso = 2)
		SET @flag_distribuida = 0;
	ELSE
		SET @flag_distribuida = 1;

	IF (
			@codigo_operacion = 'COM'
			AND @codigo_tipo = 'EFECTIVO'
			)
	BEGIN
		SET @flag_contracargo = 0;
		SET @flag_notificado = 0;
	END
	ELSE IF (@codigo_operacion = 'CON')
	BEGIN
		SET @flag_contracargo = 1;
		SET @flag_notificado = 1;
	END
	ELSE
	BEGIN
		SET @flag_contracargo = 0;
		SET @flag_notificado = 1;
	END

	SELECT @id_conciliacion = ISNULL(MAX([id_conciliacion]), 0) + 1
	FROM dbo.Conciliacion;

	INSERT INTO Configurations.dbo.Conciliacion (
		id_conciliacion,
		id_transaccion,
		id_log_paso,
		flag_aceptada_marca,
		flag_conciliada,
		flag_distribuida,
		flag_contracargo,
		id_movimiento_mp,
		flag_notificado,
		fecha_alta,
		usuario_alta,
		id_disputa,
		version
		)
	VALUES (
		@id_conciliacion,
		@idTransaccion,
		@id_log_paso_padre,
		@flag_aceptada_marca,
		@flag_conciliada,
		@flag_distribuida,
		@flag_contracargo,
		@id_movimiento_presentado,
		@flag_notificado,
		GETDATE(),
		@usuario,
		@id_disputa,
		0
		);

	IF (
			@ESTADO <> 'PENDIENTE'
			AND @codigo_tipo = 'EFECTIVO'
			)
	BEGIN
		SELECT @importe = mpm.importe,
			@moneda = mpm.moneda,
			@cantidad_cuotas = mpm.cantidad_cuotas,
			@nro_tarjeta = mpm.nro_tarjeta,
			@fecha_movimiento = mpm.fecha_movimiento,
			@nro_autorizacion = mpm.nro_autorizacion,
			@nro_cupon = mpm.nro_cupon,
			@cargos_marca_por_movimiento = mpm.cargos_marca_por_movimiento,
			@signo_cargos_marca_por_movimiento = mpm.signo_cargos_marca_por_movimiento,
			@nro_agrupador_boton = mpm.nro_agrupador_boton,
			@fecha_pago = mpm.fecha_pago,
			@ID_PASO_PROCESO = lpp.ID_PASO_PROCESO
		FROM Configurations.dbo.Movimiento_Presentado_MP AS mpm,
			Configurations.dbo.LOG_PASO_PROCESO AS lpp
		WHERE mpm.id_movimiento_mp = @id_movimiento_presentado
			AND lpp.ID_LOG_PASO = @id_log_paso_padre

		SELECT @id_conciliacion_manual = ISNULL(MAX([id_conciliacion_manual]), 0) + 1
		FROM Configurations.dbo.Conciliacion_manual;

		INSERT INTO Configurations.dbo.Conciliacion_Manual (
			id_conciliacion_manual,
			id_transaccion,
			importe,
			moneda,
			cantidad_cuotas,
			nro_tarjeta,
			fecha_movimiento,
			nro_autorizacion,
			nro_cupon,
			nro_agrupador_boton,
			cargos_marca_por_movimiento,
			signo_cargos_marca_por_movimiento,
			fecha_pago,
			id_log_paso,
			fecha_alta,
			usuario_alta,
			flag_aceptada_marca,
			flag_contracargo,
			flag_conciliado_manual,
			flag_procesado,
			impuestos_boton_por_movimiento,
			cargos_boton_por_movimiento,
			id_movimiento_mp,
			version
			)
		VALUES (
			@id_conciliacion_manual,
			@idTransaccion,
			@importe,
			@moneda,
			@cantidad_cuotas,
			@nro_tarjeta,
			@fecha_movimiento,
			@nro_autorizacion,
			@nro_cupon,
			@nro_agrupador_boton,
			@cargos_marca_por_movimiento,
			@signo_cargos_marca_por_movimiento,
			@fecha_pago,
			@id_log_paso_padre,
			GETDATE(),
			@usuario,
			@flag_aceptada_marca,
			@flag_contracargo,
			0,
			0,
			@TaxAmount,
			@FeeAmount,
			@id_movimiento_presentado,
			0
			)
	END
END TRY

BEGIN CATCH
	ROLLBACK TRANSACTION;

	SELECT @msg = ERROR_MESSAGE();

	THROW 51000,
		@msg,
		1;
END CATCH;

COMMIT TRANSACTION;

RETURN 1;

GO
/****** Object:  StoredProcedure [dbo].[Actualizar_FlagFacturacion_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Actualizar_FlagFacturacion_Cuenta] (
	@vid_cuenta INT = NULL
)            
AS

DECLARE @msg VARCHAR(255) = NULL;

SET NOCOUNT ON;

BEGIN TRANSACTION;

BEGIN TRY

	UPDATE [dbo].[Cuenta]
	SET
		[flag_informado_a_facturacion] = 1
	WHERE [id_cuenta] = @vid_cuenta;

END TRY
BEGIN CATCH
	ROLLBACK TRANSACTION;
	SELECT @msg  = ERROR_MESSAGE();
	THROW  51000, @msg, 1;
END CATCH;

COMMIT TRANSACTION;

RETURN 1;

GO
/****** Object:  StoredProcedure [dbo].[Analizar_Saldos_Por_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[Analizar_Saldos_Por_Cuenta] (@p_id_cuenta INT = NULL)
AS
/*
	ANALIZAR SALDOS POR CUENTA
	
	- Guarda un detalle de los movimientos (Ventas, Devoluciones, Cashout, Ajustes
	y Contracargos) de la Cuenta en la tabla Configurations.dbo.Analisis_Saldos_Tmp.
	
	- Busca un Log de Movimiento de Cuenta Virtual para cada ítem del detalle y lo
	agrega al registro correspondiente.
	
*/
-- Constantes de tipo de movimientos
DECLARE @tipo_transaccion CHAR(3) = 'VEN';
DECLARE @tipo_devolucion CHAR(3) = 'DEV';
DECLARE @tipo_cashout CHAR(3) = 'CSH';
DECLARE @tipo_ajuste CHAR(3) = 'AJU';
DECLARE @tipo_contracargo CHAR(3) = 'CCG';
-- Variables
DECLARE @i INT = 1;
DECLARE @count INT;
DECLARE @tipo CHAR(3);
DECLARE @temp TABLE (
	i INT PRIMARY KEY identity(1, 1),
	id_cuenta INT,
	id_log_proceso INT
	);
DECLARE @id_cuenta INT;
DECLARE @id_log_proceso INT;

BEGIN
	-- Verificar que se haya indicado una Cuenta existente
	IF (
			(
				SELECT count(1)
				FROM Configurations.dbo.Cuenta
				WHERE id_cuenta = @p_id_cuenta
				) <> 1
			)
	BEGIN
		throw 51000,
			'La Cuenta no existe.',
			1;
	END

	-- Vaciar tabla temporal
	--TRUNCATE TABLE Configurations.dbo.Analisis_Saldos_Tmp;

	-- Llenar tabla temporal con los movimientos
	BEGIN TRY
		BEGIN TRANSACTION;

		INSERT INTO Configurations.dbo.Analisis_Saldos_Tmp (
			i,
			tipo,
			id_char,
			id_int,
			id_cuenta,
			importe,
			fecha,
			id_log_proceso,
			fecha_inicio_ejecucion,
			fecha_fin_ejecucion,
			id_log_movimiento
			)
		SELECT ROW_NUMBER() OVER (
				ORDER BY m.tipo
				),
			m.*
		FROM (
			-- Ventas
			SELECT @tipo_transaccion AS tipo,
				transacciones.Id AS id_char,
				NULL AS id_int,
				transacciones.id_cuenta,
				transacciones.importe,
				transacciones.LiquidationTimestamp AS fecha,
				lpo.id_log_proceso,
				lpo.fecha_inicio_ejecucion,
				lpo.fecha_fin_ejecucion,
				NULL AS id_log_movimiento
			FROM (
				SELECT trn.Id,
					trn.LocationIdentification AS id_cuenta,
					(trn.Amount - trn.FeeAmount - trn.TaxAmount) AS importe,
					trn.LiquidationTimestamp
				FROM Transactions.dbo.transactions trn
				WHERE trn.ResultCode = - 1
					AND trn.OperationName <> 'devolucion'
					AND trn.LiquidationStatus = - 1
					AND (
						@p_id_cuenta IS NULL
						OR trn.LocationIdentification = @p_id_cuenta
						)
				) transacciones
			LEFT JOIN Configurations.dbo.Log_Proceso lpo
				ON transacciones.LiquidationTimestamp BETWEEN lpo.fecha_inicio_ejecucion
						AND lpo.fecha_fin_ejecucion
					AND lpo.id_proceso = 1
			
			UNION ALL
			
			-- Devoluciones
			SELECT @tipo_devolucion AS tipo,
				devoluciones.Id AS id_char,
				NULL AS id_int,
				devoluciones.id_cuenta,
				devoluciones.importe,
				devoluciones.CreateTimestamp AS fecha,
				NULL AS id_log_proceso,
				NULL AS fecha_inicio_ejecucion,
				NULL AS fecha_fin_ejecucion,
				NULL AS id_log_movimiento
			FROM (
				SELECT trn.Id,
					trn.LocationIdentification AS id_cuenta,
					((trn.Amount - isnull(trn.FeeAmount, 0) - isnull(trn.TaxAmount, 0)) * - 1) AS importe,
					trn.CreateTimestamp
				FROM Transactions.dbo.transactions trn
				WHERE trn.ResultCode = - 1
					AND trn.OperationName = 'devolucion'
					AND (
						@p_id_cuenta IS NULL
						OR trn.LocationIdentification = @p_id_cuenta
						)
				) devoluciones
			
			UNION ALL
			
			-- Cashout			
			SELECT @tipo_cashout AS tipo,
				NULL AS id_char,
				cashout.id_retiro_dinero AS id_int,
				cashout.id_cuenta,
				cashout.importe_cashout AS importe,
				cashout.fecha_alta AS fecha,
				NULL AS id_log_proceso,
				NULL AS fecha_inicio_ejecucion,
				NULL AS fecha_fin_ejecucion,
				NULL AS id_log_movimiento
			FROM (
				SELECT rdo.id_retiro_dinero,
					rdo.id_cuenta,
					(rdo.monto * - 1) AS importe_cashout,
					rdo.fecha_alta
				FROM Configurations.dbo.Retiro_Dinero rdo
				WHERE rdo.estado_transaccion = 'TX_APROBADA'
					AND (
						@p_id_cuenta IS NULL
						OR rdo.id_cuenta = @p_id_cuenta
						)
				) cashout
			
			UNION ALL
			
			-- Ajustes
			SELECT @tipo_ajuste AS tipo,
				NULL AS id_char,
				ajustes.id_ajuste AS id_int,
				ajustes.id_cuenta,
				ajustes.importe_ajuste AS importe,
				ajustes.fecha_alta AS fecha,
				NULL AS id_log_proceso,
				NULL AS fecha_inicio_ejecucion,
				NULL AS fecha_fin_ejecucion,
				NULL AS id_log_movimiento
			FROM (
				SELECT aje.id_ajuste,
					aje.id_cuenta,
					(
						CASE 
							WHEN cop.signo = '+'
								THEN aje.monto
							ELSE (aje.monto * - 1)
							END
						) AS importe_ajuste,
					aje.fecha_alta
				FROM Configurations.dbo.Ajuste aje
				INNER JOIN Configurations.dbo.Codigo_Operacion cop
					ON cop.id_codigo_operacion = aje.id_codigo_operacion
				WHERE @p_id_cuenta IS NULL
					OR aje.id_cuenta = @p_id_cuenta
				) ajustes
			
			UNION ALL
			
			-- Contracargos
			SELECT @tipo_contracargo AS tipo,
				contracargos.id_transaccion AS id_char,
				contracargos.id_disputa AS id_int,
				contracargos.id_cuenta,
				contracargos.importe_contracargo AS importe,
				contracargos.fecha_alta AS fecha,
				contracargos.id_log_proceso AS id_log_proceso,
				contracargos.fecha_inicio_ejecucion AS fecha_inicio_ejecucion,
				contracargos.fecha_fin_ejecucion AS fecha_fin_ejecucion,
				NULL AS id_log_movimiento
			FROM (
				SELECT dta.id_transaccion,
					dta.id_disputa,
					dta.id_cuenta,
					(trn.Amount * - 1) AS importe_contracargo,
					dta.fecha_resolucion_cuenta AS fecha_alta,
					lpo.id_log_proceso,
					lpo.fecha_inicio_ejecucion,
					lpo.fecha_fin_ejecucion
				FROM Configurations.dbo.Disputa dta
				INNER JOIN Transactions.dbo.transactions trn
					ON dta.id_transaccion = trn.Id
				LEFT JOIN Configurations.dbo.Log_Proceso lpo
					ON dta.id_log_proceso = lpo.id_log_proceso
				WHERE dta.id_estado_resolucion_cuenta = 38
					AND dta.id_estado_resolucion_mp = 38
					AND trn.ChargebackStatus = 1
					AND (
						@p_id_cuenta IS NULL
						OR dta.id_cuenta = @p_id_cuenta
						)
				) contracargos
			) m;

		COMMIT TRANSACTION;
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION;

		PRINT 'Error buscando movimientos.';

		throw;
	END CATCH

	-- Asignar Log de Movimientos de Cuenta Virtual
	BEGIN TRY
		BEGIN TRANSACTION;

		-- Para cada movimiento encontrado
		SELECT @count = count(1)
		FROM Configurations.dbo.Analisis_Saldos_Tmp;

		WHILE (@i <= @count)
		BEGIN
			-- Obtener el tipo de movimiento
			SELECT @tipo = ast.tipo
			FROM Configurations.dbo.Analisis_Saldos_Tmp ast
			WHERE ast.i = @i;

			-- Si es Transacción
			IF (@tipo = @tipo_transaccion)
				UPDATE Configurations.dbo.Analisis_Saldos_Tmp
				SET id_log_movimiento = (
						SELECT TOP 1 lmcv.id_log_movimiento
						FROM Configurations.dbo.Log_Movimiento_Cuenta_Virtual lmcv
						INNER JOIN Configurations.dbo.Analisis_Saldos_Tmp trn
							ON lmcv.id_log_proceso = trn.id_log_proceso
								AND lmcv.id_cuenta = trn.id_cuenta
								AND lmcv.monto_saldo_cuenta = trn.importe
						WHERE trn.i = @i
							AND NOT EXISTS (
								SELECT 1
								FROM Configurations.dbo.Analisis_Saldos_Tmp t
								WHERE t.id_log_movimiento = lmcv.id_log_movimiento
								)
						)
				WHERE i = @i;

			-- Si es Devolución
			IF (@tipo = @tipo_devolucion)
				UPDATE Configurations.dbo.Analisis_Saldos_Tmp
				SET id_log_movimiento = (
						SELECT TOP 1 lmcv.id_log_movimiento
						FROM Configurations.dbo.Log_Movimiento_Cuenta_Virtual lmcv
						INNER JOIN Configurations.dbo.Analisis_Saldos_Tmp trn
							ON lmcv.id_cuenta = trn.id_cuenta
						WHERE lmcv.id_log_proceso IS NULL
							AND lmcv.id_tipo_origen_movimiento = 60
							AND lmcv.monto_saldo_cuenta = trn.importe
							AND NOT EXISTS (
								SELECT 1
								FROM Configurations.dbo.Analisis_Saldos_Tmp t
								WHERE t.id_log_movimiento = lmcv.id_log_movimiento
								)
							AND trn.i = @i
						)
				WHERE i = @i;

			-- Si es Cashout
			IF (@tipo = @tipo_cashout)
				UPDATE Configurations.dbo.Analisis_Saldos_Tmp
				SET id_log_movimiento = (
						SELECT TOP 1 lmcv.id_log_movimiento
						FROM Configurations.dbo.Log_Movimiento_Cuenta_Virtual lmcv
						INNER JOIN Configurations.dbo.Analisis_Saldos_Tmp trn
							ON lmcv.id_cuenta = trn.id_cuenta
						WHERE lmcv.id_log_proceso IS NULL
							AND lmcv.id_tipo_origen_movimiento = 69
							AND lmcv.monto_saldo_cuenta = trn.importe
							AND NOT EXISTS (
								SELECT 1
								FROM Configurations.dbo.Analisis_Saldos_Tmp t
								WHERE t.id_log_movimiento = lmcv.id_log_movimiento
								)
							AND trn.i = @i
						)
				WHERE i = @i;

			-- Si es Contracargo
			IF (@tipo = @tipo_contracargo)
				UPDATE Configurations.dbo.Analisis_Saldos_Tmp
				SET id_log_movimiento = (
						SELECT TOP 1 lmcv.id_log_movimiento
						FROM Configurations.dbo.Log_Movimiento_Cuenta_Virtual lmcv
						INNER JOIN Configurations.dbo.Analisis_Saldos_Tmp trn
							ON lmcv.id_cuenta = trn.id_cuenta
						WHERE lmcv.id_tipo_movimiento = 58
							AND lmcv.id_tipo_origen_movimiento = 59
							AND lmcv.fecha_alta >= trn.fecha
							AND lmcv.monto_saldo_cuenta = trn.importe
							AND NOT EXISTS (
								SELECT 1
								FROM Configurations.dbo.Analisis_Saldos_Tmp t
								WHERE t.id_log_movimiento = lmcv.id_log_movimiento
								)
							AND trn.i = @i
						ORDER BY lmcv.fecha_alta
						)
				WHERE i = @i;

			SET @i += 1;
		END;

		COMMIT TRANSACTION;
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION;

		PRINT 'Error buscando log de cuenta virtual.';

		throw;
	END CATCH

	-- Asignar Log de Movimientos de Cuenta Virtual para Ventas Liquidadas con el nuevo Liquidador
	BEGIN TRY
		BEGIN TRANSACTION;

		INSERT INTO @temp (
			id_cuenta,
			id_log_proceso
			)
		SELECT DISTINCT ast.id_cuenta,
			ast.id_log_proceso
		FROM Configurations.dbo.Analisis_Saldos_Tmp ast
		WHERE ast.id_log_movimiento IS NULL;

		SET @i = 1;

		SELECT @count = count(1)
		FROM @temp;

		WHILE (@i <= @count)
		BEGIN
			SELECT @id_cuenta = id_cuenta,
				@id_log_proceso = id_log_proceso
			FROM @temp
			WHERE i = @i;

			UPDATE Configurations.dbo.Analisis_Saldos_Tmp
			SET id_log_movimiento = (
					SELECT TOP 1 mov.id_log_movimiento
					FROM (
						SELECT ast.id_cuenta,
							ast.id_log_proceso,
							sum(ast.importe) AS importe
						FROM Analisis_Saldos_Tmp ast
						WHERE ast.tipo = 'VEN'
							AND ast.id_log_movimiento IS NULL
							AND ast.id_cuenta = @id_cuenta
							AND ast.id_log_proceso = @id_log_proceso
						GROUP BY ast.id_cuenta,
							ast.id_log_proceso
						) ven
					INNER JOIN (
						SELECT lmcv.id_cuenta,
							lmcv.id_log_proceso,
							lmcv.monto_saldo_cuenta AS importe,
							lmcv.id_log_movimiento
						FROM Log_Movimiento_Cuenta_Virtual lmcv
						WHERE NOT EXISTS (
								SELECT 1
								FROM Analisis_Saldos_Tmp ast
								WHERE ast.id_log_movimiento = lmcv.id_log_movimiento
								)
						) mov
						ON ven.id_cuenta = mov.id_cuenta
							AND ven.id_log_proceso = mov.id_log_proceso
							AND ven.importe = mov.importe
					)
			WHERE id_cuenta = @id_cuenta
				AND id_log_proceso = @id_log_proceso;

			SET @i += 1;
		END;

		COMMIT TRANSACTION;
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION;

		PRINT 'Error buscando log de cuenta virtual para ventas liquidadas con el nuevo liquidador.';

		throw;
	END CATCH

	RETURN 1;
END
GO
/****** Object:  StoredProcedure [dbo].[Batch_Actividad_TX_Cuenta_Compradora]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
 
CREATE PROCEDURE [dbo].[Batch_Actividad_TX_Cuenta_Compradora] (   
 @id_proceso INT = NULL   
 ,@fecha_desde_proceso CHAR(8) = NULL --aaaammdd   
 ,@fecha_hasta_proceso CHAR(8) = NULL --aaaammdd   
 ,@usuario VARCHAR(20) = NULL   
 )   
AS   
DECLARE @msg VARCHAR(300);   
DECLARE @version INT = 1;   
DECLARE @id_log_proceso INT;   
DECLARE @flag_ok INT;   
DECLARE @registros_afectados INT;   
DECLARE @fecha_desde DATETIME;   
DECLARE @fecha_hasta DATETIME;   
DECLARE @MergeRowCount TABLE (MergeAction VARCHAR(20));   
    
SET NOCOUNT ON;   
    
BEGIN TRY   
 BEGIN TRANSACTION;   
    
 IF (@id_proceso IS NULL) THROW 51000   
  ,'El parametro Id Proceso tiene valor Nulo'   
  ,1;   
  IF (   
    NOT EXISTS (   
     SELECT 1   
     FROM [dbo].[Proceso]   
     WHERE [id_proceso] = @id_proceso   
     )   
    ) THROW 51000   
   ,'No existe Proceso con el Id indicado'   
   ,1;       
 IF (@usuario IS NULL) THROW 51000   
     ,'El parametro Usuario tiene valor Nulo'   
     ,1;   
 
   
 --Si no hay parametros establecer x default el día anterior   
 IF (@fecha_desde_proceso IS NULL)       
 BEGIN     
  SET @fecha_desde = CAST(CAST(GETDATE() -1 AS DATE) AS DATETIME);     
  SET @fecha_hasta = @fecha_desde;   
 END     
     
 --Si se indica una sola fecha filtrar solo por ese dia     
 ELSE IF (@fecha_hasta_proceso IS NULL)     
 BEGIN       
  SET @fecha_desde = CAST(@fecha_desde_proceso AS DATETIME);    
  SET @fecha_hasta = @fecha_desde;    
 END     
 ELSE     
 BEGIN     
  SET @fecha_desde = CAST(@fecha_desde_proceso AS DATETIME);    
  SET @fecha_hasta = CAST(@fecha_hasta_proceso AS DATETIME);    
 END;     
     
 SET @fecha_hasta = DATEADD(s, -1, @fecha_hasta)+1;    
 
 -- Iniciar Log     
 EXEC @id_log_proceso = Configurations.dbo.Iniciar_Log_Proceso @id_proceso   
      ,@fecha_desde   
      ,@fecha_hasta
      ,@Usuario;    
    
 --Obtener actividad x cta./Actualizar   
 MERGE Configurations.dbo.Actividad_MP_Cuenta AS destino   
 USING (   
  SELECT tx.id_medio_pago_cuenta AS id_medio_pago_cuenta   
   ,COUNT(1) AS cantidad   
   ,SUM(tx.importe) AS importe   
   ,tx.fecha_procesada AS fecha_procesada   
   ,@id_log_proceso AS id_log_proceso   
   ,GETDATE() AS fecha_actual   
   ,@usuario AS usuario   
   ,NULL AS fecha_modificacion   
   ,NULL AS usuario_modificacion   
   ,NULL AS fecha_baja   
   ,NULL AS usuario_baja   
   ,@version AS version   
  FROM (   
   -- TARJETAS   
   SELECT    
    trn.id_medio_pago_cuenta AS id_medio_pago_cuenta   
 ,trn.BuyerAccountIdentification AS id_cta_compradora   
    ,CAST(CAST(trn.CreateTimestamp AS DATE) AS DATETIME) AS fecha_procesada   
    ,LTRIM(RTRIM(tmp.codigo)) AS tipo_tx   
    ,trn.Amount AS importe   
   FROM Transactions.dbo.transactions trn   
    ,Configurations.dbo.Medio_De_Pago mdp   
    ,Configurations.dbo.Tipo_Medio_Pago tmp   
    ,Configurations.dbo.Medio_Pago_Cuenta mpc   
   WHERE trn.ProductIdentification = mdp.id_medio_pago
    AND mpc.fecha_baja IS NULL  
    AND mdp.id_tipo_medio_pago = tmp.id_tipo_medio_pago   
    AND LTRIM(RTRIM(tmp.codigo)) IN (   
     'CREDITO'   
     ,'DEBITO'   
     )   
    AND LTRIM(RTRIM(trn.OperationName)) IN (   
     'Compra_offline'   
     ,'Compra_online'   
     )   
    AND trn.ResultCode = - 1   
    AND trn.ReverseStatus IS NULL   
    AND (   
     trn.ButtonId IS NULL   
     OR EXISTS (   
      SELECT 1   
      FROM Configurations.dbo.Boton btn WITH (NOLOCK)   
       ,Configurations.dbo.Tipo tpo WITH (NOLOCK)   
      WHERE trn.ButtonId = btn.id_boton   
       AND btn.id_tipo_concepto_boton = tpo.id_tipo   
       AND tpo.id_grupo_tipo = 12   
       AND LTRIM(RTRIM(tpo.codigo)) = 'CPTO_BTN_VTA'   
      )   
     )   
    AND trn.CreateTimestamp BETWEEN @fecha_desde AND @fecha_hasta    
    AND trn.BuyerAccountIdentification IS NOT NULL   
    AND trn.BuyerAccountIdentification = mpc.id_cuenta   
    AND trn.id_medio_pago_cuenta = mpc.id_medio_pago_cuenta   
   ) tx   
  GROUP BY tx.id_medio_pago_cuenta   
   ,tx.id_cta_compradora      ,tx.fecha_procesada   
   ,tx.tipo_tx   
  ) AS origen(id_medio_pago_cuenta, cantidad, importe, fecha_procesada, id_log_proceso, fecha_actual, usuario, fecha_modificacion, usuario_modificacion, fecha_baja, usuario_baja, version)   
  ON (   
    destino.id_mp_cuenta = origen.id_medio_pago_cuenta   
    AND destino.fecha_compra = origen.fecha_procesada   
    )   
 WHEN MATCHED   
  THEN   
   UPDATE   
   SET destino.cant_tx_dia = origen.cantidad   
    ,destino.monto_tx_dia = origen.importe   
 WHEN NOT MATCHED   
  THEN   
   INSERT (   
    id_mp_cuenta   
    ,cant_tx_dia   
    ,monto_tx_dia   
    ,fecha_compra   
    ,id_log_proceso   
    ,fecha_alta   
    ,usuario_alta   
    ,fecha_modificacion   
    ,usuario_modificacion   
    ,fecha_baja   
    ,usuario_baja   
    ,version   
    )   
   VALUES (   
    origen.id_medio_pago_cuenta   
    ,origen.cantidad   
    ,origen.importe   
    ,origen.fecha_procesada   
    ,origen.id_log_proceso   
    ,origen.fecha_actual   
    ,origen.usuario   
    ,origen.fecha_modificacion   
    ,origen.usuario_modificacion   
    ,origen.fecha_baja   
    ,origen.usuario_baja   
    ,origen.version   
    )   
    
 OUTPUT $action INTO @MergeRowCount;   
 SET @registros_afectados = (SELECT COUNT(*) FROM @MergeRowCount);   
    
 -- Completar Log de Proceso   
 EXEC @flag_ok = Configurations.dbo.Finalizar_Log_Proceso @id_log_proceso   
  ,@registros_afectados   
  ,@Usuario;   
    
  COMMIT TRANSACTION;   
END TRY   
    
BEGIN CATCH   
     
 IF(@@TRANCOUNT > 0)   
  ROLLBACK TRANSACTION;   
    
 SELECT @msg = ERROR_MESSAGE();   
    
 THROW 51000   
  ,@msg   
  ,1;   
END CATCH;   
 

GO
/****** Object:  StoredProcedure [dbo].[Batch_Actualizar_Control_Liquidacion_Disponible]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
  
CREATE PROCEDURE [dbo].[Batch_Actualizar_Control_Liquidacion_Disponible]  
 @id_log_proceso INT = NULL,  
 @id_transaccion CHAR(36) = NULL,  
 @fecha_base_de_cashout DATE = NULL,  
 @fecha_de_cashout DATE = NULL,  
 @id_cuenta INT = NULL,  
 @id_codigo_operacion INT = NULL,  
 @importe DECIMAL(12, 2) = NULL  
AS  
 DECLARE @ret INT = 1;  
 DECLARE @msg VARCHAR(MAX);  
BEGIN  
 SET NOCOUNT ON;  
  
 BEGIN TRY  
  
  MERGE  
   Configurations.dbo.Control_Liquidacion_Disponible AS destino  
   USING (  
    SELECT  
     @fecha_base_de_cashout,  
     @fecha_de_cashout,  
     @id_cuenta,  
     @id_codigo_operacion,  
     (CASE WHEN cop.signo = '-' THEN @importe * -1 ELSE @importe END) AS importe  
    FROM Configurations.dbo.Codigo_Operacion cop  
    WHERE cop.id_codigo_operacion = @id_codigo_operacion  
   ) AS origen (  
     fecha_base_de_cashout,  
     fecha_de_cashout,  
     id_cuenta,  
     id_codigo_operacion,  
     importe  
   )  
   ON (destino.fecha_base_de_cashout = origen.fecha_base_de_cashout  
   AND destino.fecha_de_cashout = origen.fecha_de_cashout  
   AND destino.id_cuenta = origen.id_cuenta  
   AND destino.id_codigo_operacion = origen.id_codigo_operacion)  
  WHEN MATCHED THEN  
   UPDATE SET destino.importe = destino.importe + origen.importe  
  WHEN NOT MATCHED THEN  
   INSERT (fecha_base_de_cashout,  
     fecha_de_cashout,  
     id_cuenta,  
     id_codigo_operacion,  
     importe)  
   VALUES (origen.fecha_base_de_cashout,  
     origen.fecha_de_cashout,  
     origen.id_cuenta,  
     origen.id_codigo_operacion,  
     origen.importe);  
  
  INSERT INTO Configurations.dbo.Log_Control_Liquidacion_Disponible (  
   id_log_proceso,  
   id_transaccion,  
   importe  
  ) VALUES (  
   @id_log_proceso,  
   @id_transaccion,  
   @importe  
  );  
  
 END TRY  
  
 BEGIN CATCH  
  SELECT @msg  = ERROR_MESSAGE();  
  THROW  51000, @msg , 1;  
 END CATCH;  
  
 RETURN @ret;  
END;  
GO
/****** Object:  StoredProcedure [dbo].[Batch_Concil_Actualizar_Conciliacion_Manual]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Concil_Actualizar_Conciliacion_Manual]
AS
SET NOCOUNT ON;

DECLARE @msg VARCHAR(255) = NULL;

BEGIN TRANSACTION;

BEGIN TRY
	BEGIN
		UPDATE dbo.Conciliacion_Manual
		SET flag_procesado = 1
		WHERE id_transaccion IS NULL
			AND flag_conciliado_manual = 1
	END
END TRY

BEGIN CATCH
	ROLLBACK TRANSACTION;

	SELECT @msg = ERROR_MESSAGE();

	THROW 51000,
		@msg,
		1;
END CATCH;

COMMIT TRANSACTION;

RETURN 1;

GO
/****** Object:  StoredProcedure [dbo].[Batch_Concil_Actualizar_Cupones]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Concil_Actualizar_Cupones] (
	@idTransaccion CHAR(36),
	@id_log_paso_padre INT,
	@usuario VARCHAR(20),
	@id_movimiento_presentado INT,
	@codigo_tipo VARCHAR(15)
	)
AS
DECLARE @id_paso INT = 0;
DECLARE @flag_aceptada_marca BIT;
DECLARE @flag_conciliada BIT;
DECLARE @flag_distribuida BIT;
DECLARE @flag_contracargo BIT;
DECLARE @flag_notificado BIT;
DECLARE @Estado VARCHAR(20);
DECLARE @fecha_pago DATETIME;
DECLARE @importe DECIMAL(12, 2);
DECLARE @moneda INT;
DECLARE @cantidad_cuotas INT;
DECLARE @nro_tarjeta VARCHAR(50);
DECLARE @fecha_movimiento DATETIME;
DECLARE @nro_autorizacion VARCHAR(50);
DECLARE @nro_cupon VARCHAR(50);
DECLARE @cargos_marca_por_movimiento DECIMAL(12, 2);
DECLARE @signo_cargos_marca_por_movimiento VARCHAR(1);
DECLARE @nro_agrupador_boton VARCHAR(50);
DECLARE @ID_PASO_PROCESO INT;
DECLARE @id_conciliacion INT;
DECLARE @id_disputa BIT = NULL;
DECLARE @id_conciliacion_manual INT;
DECLARE @msg VARCHAR(255) = NULL;
DECLARE @FeeAmount DECIMAL(12, 2);
DECLARE @TaxAmount DECIMAL(12, 2);
DECLARE @productidentification INT;
DECLARE @codigo_operacion VARCHAR(5);

SET NOCOUNT ON;

BEGIN TRANSACTION;

BEGIN TRY
	SELECT @Estado = CouponStatus,
		@FeeAmount = FeeAmount,
		@TaxAmount = TaxAmount,
		@productidentification = Productidentification 
	FROM Transactions.dbo.transactions
	WHERE Id = @idTransaccion;

	SELECT @fecha_pago = mpm.fecha_pago, 
	       @codigo_operacion = co.codigo_operacion
	FROM Configurations.dbo.Movimiento_Presentado_MP mpm
	INNER JOIN Configurations.dbo.Codigo_operacion co ON mpm.id_codigo_operacion = co.id_codigo_operacion
	WHERE mpm.id_movimiento_mp = @id_movimiento_presentado;

	IF (@codigo_tipo = 'EFECTIVO')
	BEGIN
		UPDATE Transactions.dbo.transactions
		SET PaymentTimestamp = @fecha_pago,
			ReconciliationStatus = 1,
			ReconciliationTimestamp = GETDATE(),
			SyncStatus = 0,
			CouponStatus = 'ACREDITADO',
			TransactionStatus = 'TX_PROCESADA'
		WHERE Id = @idTransaccion;
	END
	ELSE
	BEGIN
		UPDATE Transactions.dbo.transactions
		SET PaymentTimestamp = @fecha_pago,
			ReconciliationStatus = 1,
			ReconciliationTimestamp = GETDATE(),
			SyncStatus = 0
		WHERE Id = @idTransaccion;

		SET @id_disputa = 0;
	END

	SET @flag_aceptada_marca = 1;
	SET @flag_conciliada = 1;

	SELECT @id_paso = ID_PASO_PROCESO
	FROM Configurations.dbo.LOG_PASO_PROCESO
	WHERE ID_LOG_PASO = @id_log_paso_padre;

	IF (@id_paso = 2)
		SET @flag_distribuida = 0;
	ELSE
		SET @flag_distribuida = 1;

	IF (
			@codigo_operacion = 'COM'
			AND @codigo_tipo = 'EFECTIVO'
			)
	BEGIN
		SET @flag_contracargo = 0;
		SET @flag_notificado = 0;
	END
	ELSE IF (@codigo_operacion = 'CON')
	BEGIN
		SET @flag_contracargo = 1;
		SET @flag_notificado = 1;
	END
	ELSE
	BEGIN
		SET @flag_contracargo = 0;
		SET @flag_notificado = 1;
	END

	SELECT @id_conciliacion = ISNULL(MAX([id_conciliacion]), 0) + 1
	FROM dbo.Conciliacion;

	INSERT INTO Configurations.dbo.Conciliacion (
		id_conciliacion,
		id_transaccion,
		id_log_paso,
		flag_aceptada_marca,
		flag_conciliada,
		flag_distribuida,
		flag_contracargo,
		id_movimiento_mp,
		flag_notificado,
		fecha_alta,
		usuario_alta,
		id_disputa,
		version
		)
	VALUES (
		@id_conciliacion,
		@idTransaccion,
		@id_log_paso_padre,
		@flag_aceptada_marca,
		@flag_conciliada,
		@flag_distribuida,
		@flag_contracargo,
		@id_movimiento_presentado,
		@flag_notificado,
		GETDATE(),
		@usuario,
		@id_disputa,
		0
		);

	IF (
			@ESTADO <> 'PENDIENTE'
			AND @codigo_tipo = 'EFECTIVO'
			)
	BEGIN
		SELECT @importe = mpm.importe,
			@moneda = mpm.moneda,
			@cantidad_cuotas = mpm.cantidad_cuotas,
			@nro_tarjeta = mpm.nro_tarjeta,
			@fecha_movimiento = mpm.fecha_movimiento,
			@nro_autorizacion = mpm.nro_autorizacion,
			@nro_cupon = mpm.nro_cupon,
			@cargos_marca_por_movimiento = mpm.cargos_marca_por_movimiento,
			@signo_cargos_marca_por_movimiento = mpm.signo_cargos_marca_por_movimiento,
			@nro_agrupador_boton = mpm.nro_agrupador_boton,
			@fecha_pago = mpm.fecha_pago,
			@ID_PASO_PROCESO = lpp.ID_PASO_PROCESO
		FROM Configurations.dbo.Movimiento_Presentado_MP AS mpm,
			Configurations.dbo.LOG_PASO_PROCESO AS lpp
		WHERE mpm.id_movimiento_mp = @id_movimiento_presentado
			AND lpp.ID_LOG_PASO = @id_log_paso_padre

		SELECT @id_conciliacion_manual = ISNULL(MAX([id_conciliacion_manual]), 0) + 1
		FROM Configurations.dbo.Conciliacion_manual;

		INSERT INTO Configurations.dbo.Conciliacion_Manual (
			id_conciliacion_manual,
			id_transaccion,
			importe,
			moneda,
			cantidad_cuotas,
			nro_tarjeta,
			fecha_movimiento,
			nro_autorizacion,
			nro_cupon,
			nro_agrupador_boton,
			cargos_marca_por_movimiento,
			signo_cargos_marca_por_movimiento,
			fecha_pago,
			id_log_paso,
			fecha_alta,
			usuario_alta,
			flag_aceptada_marca,
			flag_contracargo,
			flag_conciliado_manual,
			flag_procesado,
			impuestos_boton_por_movimiento,
			cargos_boton_por_movimiento,
			id_movimiento_mp,
			version
			)
		VALUES (
			@id_conciliacion_manual,
			@idTransaccion,
			@importe,
			@moneda,
			@cantidad_cuotas,
			@nro_tarjeta,
			@fecha_movimiento,
			@nro_autorizacion,
			@nro_cupon,
			@nro_agrupador_boton,
			@cargos_marca_por_movimiento,
			@signo_cargos_marca_por_movimiento,
			@fecha_pago,
			@id_log_paso_padre,
			GETDATE(),
			@usuario,
			@flag_aceptada_marca,
			@flag_contracargo,
			0,
			0,
			@TaxAmount,
			@FeeAmount,
			@id_movimiento_presentado,
			0
			)
	END
END TRY

BEGIN CATCH
	ROLLBACK TRANSACTION;

	SELECT @msg = ERROR_MESSAGE();

	THROW 51000,
		@msg,
		1;
END CATCH;

COMMIT TRANSACTION;

RETURN 1;

GO
/****** Object:  StoredProcedure [dbo].[Batch_Concil_Actualizar_distribucion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Concil_Actualizar_distribucion](
@usuario varchar(50)
)
AS
SET NOCOUNT ON;

DECLARE @msg VARCHAR(max);
DECLARE @id_distribucion INT;
DECLARE @i INT = 1;
DECLARE @count INT;

BEGIN
	BEGIN TRY
		-- Limpio la tabla temporal	
			TRUNCATE TABLE Distribucion_tmp;

BEGIN TRANSACTION;
		
		-- Obtengo los registros a distribuir.
		INSERT INTO Configurations.dbo.Distribucion_tmp    
		  ([id_transaccion])			
		SELECT m.id_transaccion
		FROM Configurations.dbo.Distribucion d 
		INNER JOIN Configurations.dbo.Movimientos_a_distribuir m ON d.id_transaccion = m.id_transaccion
		INNER JOIN Configurations.dbo.Medio_De_Pago mdp  ON mdp.id_medio_pago = m.id_medio_pago 
		WHERE d.flag_procesado = 0 AND d.fecha_distribucion IS NULL
		UNION 
		SELECT md.id_transaccion
		FROM Configurations.dbo.Movimientos_a_distribuir md  
		INNER JOIN Configurations.dbo.Medio_De_Pago mdp  ON mdp.id_medio_pago = md.id_medio_pago
		WHERE flag_esperando_impuestos_generales_de_marca = 1 
		AND NOT EXISTS	(SELECT 1 FROM Configurations.dbo.Distribucion dis  
						 WHERE md.id_transaccion = dis.id_transaccion
						 AND CAST(md.fecha_alta AS DATE) = CAST(fecha_alta AS DATE))

COMMIT TRANSACTION;

		
BEGIN TRANSACTION;

		
		-- Actualizar la tabla Distribucion con los movimientos a distribuir.
		
		INSERT INTO Configurations.dbo.Distribucion    
		  ([id_transaccion]
           ,[fecha_alta]
           ,[usuario_alta]     
           ,[version]
           ,[flag_procesado]
           ,[fecha_distribucion]
           )
		SELECT id_transaccion, GETDATE(), @usuario, 0 as cero, 1 as flag_procesado, GETDATE()
		FROM dbo.Distribucion_tmp 
		
		
COMMIT TRANSACTION;


	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;

		SELECT @msg = ERROR_MESSAGE();

		THROW 51000,
			@Msg,
			1;
	END CATCH;

	RETURN 1;
END;

GO
/****** Object:  StoredProcedure [dbo].[Batch_Concil_Actualizar_Flag_Impuestos]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Concil_Actualizar_Flag_Impuestos] (
   @usuario VARCHAR(20),
   @registros_procesados INT = NULL OUTPUT,
   @importe_procesados DECIMAL(12,2) = NULL OUTPUT,
   @resultado_proceso INT = 0 OUTPUT
	)
AS

DECLARE @movimientos TABLE (id_movimiento INT, importe_mov DECIMAL(12,2));

BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRANSACTION;

		-- Obtener Movimientos --
		INSERT INTO @movimientos (
		id_movimiento,
		importe_mov
		)
		SELECT mpp.id_movimiento_mp,
		       ISNULL(CASE WHEN RTRIM(LTRIM(mad.signo_importe)) = '-' THEN (mad.importe * -1)ELSE mad.importe END, 0) 
        FROM configurations.dbo.Movimientos_a_distribuir mad 
        INNER JOIN dbo.Movimiento_Presentado_MP mpp  ON mpp.id_movimiento_mp = mad.id_movimiento_mp
        INNER JOIN dbo.Impuesto_General_MP ig ON ig.id_medio_pago = mpp.id_medio_pago
        WHERE ig.solo_impuestos = 1 
        AND (CAST(mpp.fecha_pago AS DATE) BETWEEN CAST(ig.fecha_pago_desde AS DATE) AND CAST(ig.fecha_pago_hasta AS DATE))
		UNION
		SELECT mpp.id_movimiento_mp,
		       ISNULL(CASE WHEN RTRIM(LTRIM(mad.signo_importe)) = '-' THEN (mad.importe * -1)ELSE mad.importe END, 0) 
        FROM configurations.dbo.Movimientos_a_distribuir mad 
        INNER JOIN dbo.Movimiento_Presentado_MP mpp  ON mpp.id_movimiento_mp = mad.id_movimiento_mp
        WHERE mad.id_medio_pago = 500 OR mad.id_medio_pago = 501
        
		-- Obtener Resultados Para Log--
		SELECT
	    @registros_procesados = ISNULL(COUNT(*),0),
	    @importe_procesados = ISNULL(SUM(importe_mov), 0)
        FROM @movimientos 

		-- Actualizar Flag Impuestos --
	    UPDATE Configurations.dbo.Movimientos_a_distribuir
		SET flag_esperando_impuestos_generales_de_marca = 1
		WHERE id_movimiento_mp IN (
				SELECT id_movimiento
				FROM @movimientos
				);

        SET @resultado_proceso = 1;

		COMMIT TRANSACTION;

		RETURN 1;
	END TRY

	BEGIN CATCH
		PRINT ERROR_MESSAGE();

		IF (@@TRANCOUNT > 0)
			ROLLBACK TRANSACTION;

		RETURN 0;
	END CATCH
END

GO
/****** Object:  StoredProcedure [dbo].[Batch_Concil_Conciliar_Manual]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Concil_Conciliar_Manual] (
    @estado_movimiento VARCHAR(1),
	@id_log_paso INT,
	@usuario VARCHAR(20),
    @id_movimiento_mp INT,
    @codigo_tipo_mp VARCHAR(20)
	)
AS

DECLARE @flag_aceptada_marca BIT = 0;
DECLARE @flag_contracargo BIT = 0;
DECLARE @fecha_pago DATETIME;
DECLARE @importe DECIMAL(12, 2);
DECLARE @signo_importe VARCHAR(1);
DECLARE @moneda INT;
DECLARE @cantidad_cuotas INT;
DECLARE @nro_tarjeta VARCHAR(50);
DECLARE @codigo_barra VARCHAR(128);
DECLARE @fecha_movimiento DATETIME;
DECLARE @nro_autorizacion VARCHAR(50);
DECLARE @nro_cupon VARCHAR(50);
DECLARE @cargos_marca_por_movimiento DECIMAL(12, 2);
DECLARE @signo_cargos_marca_por_movimiento VARCHAR(1);
DECLARE @nro_agrupador_boton VARCHAR(50);
DECLARE @id_conciliacion_manual INT;
DECLARE @codigo_operacion VARCHAR(5);

BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRANSACTION;


		-- Obtener Datos --
		SELECT 
		    @importe = mpm.importe,
			@signo_importe = mpm.signo_importe,
			@moneda = mpm.moneda,
			@cantidad_cuotas = mpm.cantidad_cuotas,
			@nro_tarjeta = mpm.nro_tarjeta,
			@codigo_barra = mpm.codigo_barra,
			@fecha_movimiento = mpm.fecha_movimiento,
			@nro_autorizacion = mpm.nro_autorizacion,
			@nro_cupon = mpm.nro_cupon,
			@cargos_marca_por_movimiento = mpm.cargos_marca_por_movimiento,
			@signo_cargos_marca_por_movimiento = mpm.signo_cargos_marca_por_movimiento,
			@nro_agrupador_boton = mpm.nro_agrupador_boton,
			@fecha_pago = mpm.fecha_pago, 
	        @codigo_operacion = co.codigo_operacion
	    FROM Configurations.dbo.Movimiento_Presentado_MP mpm
	    INNER JOIN Configurations.dbo.Codigo_operacion co 
		    ON mpm.id_codigo_operacion = co.id_codigo_operacion
	    WHERE mpm.id_movimiento_mp = @id_movimiento_mp; 

		IF (@codigo_operacion = 'CON')
		   SET @flag_contracargo = 1;

        IF(@estado_movimiento = 'A')
		  SET @flag_aceptada_marca = 1;

        SELECT @id_conciliacion_manual = ISNULL(MAX([id_conciliacion_manual]), 0) + 1
		FROM Configurations.dbo.Conciliacion_manual;

		INSERT INTO Configurations.dbo.Conciliacion_manual(
            id_conciliacion_manual,
            importe,
            moneda,
            cantidad_cuotas,
            nro_tarjeta,
            codigo_barra,
            fecha_movimiento,
            nro_autorizacion,
            nro_cupon,
			cargos_boton_por_movimiento,
			impuestos_boton_por_movimiento,
			cargos_marca_por_movimiento,
			signo_cargos_marca_por_movimiento,
			nro_agrupador_boton,
			fecha_pago,
			flag_aceptada_marca,
			flag_conciliado_manual,
			flag_contracargo,
			flag_procesado,
			id_log_paso,
			fecha_alta,
			usuario_alta,
			id_movimiento_mp,
			version
			)
		VALUES(
			@id_conciliacion_manual,
            @importe,
			@moneda,
			@cantidad_cuotas,
			@nro_tarjeta,
			@codigo_barra,
			@fecha_movimiento,
			@nro_autorizacion,
			@nro_cupon,
			0,
			0,
			@cargos_marca_por_movimiento,
			@signo_cargos_marca_por_movimiento,
			@nro_agrupador_boton,
			@fecha_pago,
			@flag_aceptada_marca,
			0,
			@flag_contracargo,
			0,
			@id_log_paso,
			GETDATE(),
			@usuario,
			@id_movimiento_mp,
			0
			);

        -- Es aceptada o rechazada --
		IF(@codigo_tipo_mp = 'EFECTIVO' OR @estado_movimiento = 'A')
		  INSERT INTO Configurations.dbo.movimientos_a_distribuir(
				 tipo,
				 BCRA_cuenta,
				 BCRA_emisor_tarjeta,
				 signo_importe,
				 signo_cargo_marca,
				 cargo_marca,
                 signo_cargo_boton,
				 cargo_boton,
				 signo_impuesto_boton,
				 impuesto_boton,
				 id_log_paso,
				 flag_esperando_impuestos_generales_de_marca,
                 importe,
				 id_movimiento_mp,
				 fecha_alta,
				 usuario_alta,
				 version
				 )
          VALUES(
		        'N',
				0,
				0,
				@signo_importe,
				@signo_cargos_marca_por_movimiento,
				@cargos_marca_por_movimiento,
				' ',
				0,
				' ',
				0,
				@id_log_paso,
				0,
				@importe,
				@id_movimiento_mp,
				GETDATE(),
				@usuario,
				0
				);


		COMMIT TRANSACTION;

		RETURN 1;
	END TRY

	BEGIN CATCH
		PRINT ERROR_MESSAGE();

		IF (@@TRANCOUNT > 0)
			ROLLBACK TRANSACTION;

		RETURN 0;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Batch_Concil_Conciliar_Movimientos]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Concil_Conciliar_Movimientos] (
    @estado_movimiento VARCHAR(1),
	@id_transaccion VARCHAR(36),
	@id_log_paso INT,
	@usuario VARCHAR(20),
    @id_movimiento_mp INT,
    @codigo_tipo_mp VARCHAR(20)
	)
AS

BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRANSACTION;

        -- Es aceptada o rechazada --
		IF(@codigo_tipo_mp = 'EFECTIVO' OR @estado_movimiento = 'A')
		   EXEC Configurations.dbo.Batch_Concil_Actualizar_Cupones
		        @id_transaccion,
				@id_log_paso,
				@usuario,
				@id_movimiento_mp,
				@codigo_tipo_mp;
        ELSE
		   EXEC Configurations.dbo.Batch_Concil_Movimiento_Rechazado 
		        @id_movimiento_mp,
				@id_transaccion,
		        @id_log_paso,
				@usuario;

		COMMIT TRANSACTION;

		RETURN 1;
	END TRY

	BEGIN CATCH
		PRINT ERROR_MESSAGE();

		IF (@@TRANCOUNT > 0)
			ROLLBACK TRANSACTION;

		RETURN 0;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Batch_Concil_Movimiento_Rechazado]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Concil_Movimiento_Rechazado] (
    @id_movimiento_mp INT,
	@id_transaccion VARCHAR(36),
	@id_log_paso INT,
	@usuario VARCHAR(20)
	)
AS

DECLARE @importe DECIMAL(12,2);
DECLARE @moneda INT;
DECLARE @cantidad_cuotas INT;
DECLARE @nro_tarjeta VARCHAR(50);
DECLARE @fecha_movimiento DATETIME;
DECLARE @nro_autorizacion VARCHAR(50);
DECLARE @nro_cupon VARCHAR(50);
DECLARE @cargos_marca_por_movimiento DECIMAL(12,2);
DECLARE @signo_cargos_marca_por_movimiento VARCHAR(1);
DECLARE @nro_agrupador_boton VARCHAR(50);
DECLARE @fecha_pago DATETIME;
DECLARE @codigo_operacion VARCHAR(20);
DECLARE @flag_contracargo BIT;
DECLARE @TaxAmount DECIMAL(12,2);
DECLARE @FeeAmount DECIMAL(12,2);
DECLARE @id_conciliacion INT;
DECLARE @id_conciliacion_manual INT;

BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRANSACTION;

		-- Obtener Datos --
		SELECT
		   @importe = mpm.importe, 
		   @moneda = mpm.moneda,
		   @cantidad_cuotas = mpm.cantidad_cuotas,
		   @nro_tarjeta = mpm.nro_tarjeta,
		   @fecha_movimiento = mpm.fecha_movimiento,
		   @nro_autorizacion = mpm.nro_autorizacion,
	       @nro_cupon =mpm.nro_cupon,
	       @cargos_marca_por_movimiento = mpm.cargos_marca_por_movimiento,
	       @signo_cargos_marca_por_movimiento = mpm.signo_cargos_marca_por_movimiento,
	       @nro_agrupador_boton = mpm.nro_agrupador_boton,	
	       @fecha_pago = mpm.fecha_pago,
	       @codigo_operacion = co.codigo_operacion
	    FROM Configurations.dbo.Movimiento_Presentado_MP mpm
	    INNER JOIN Configurations.dbo.Codigo_operacion co ON mpm.id_codigo_operacion = co.id_codigo_operacion
	    WHERE mpm.id_movimiento_mp = @id_movimiento_mp;

		IF(@codigo_operacion = 'CON')
		   SET @flag_contracargo = 1;
        ELSE
		   SET @flag_contracargo = 0;

		SELECT 
		   @TaxAmount = t.TaxAmount,
		   @FeeAmount = t.FeeAmount 
		FROM Transactions.dbo.transactions t
		WHERE Id= @id_transaccion;

        -- Insertar en Conciliacion --
		SELECT @id_conciliacion = ISNULL(MAX(id_conciliacion), 0) + 1
	    FROM dbo.Conciliacion;
		
        INSERT INTO Configurations.dbo.Conciliacion(
		   id_conciliacion,
           id_movimiento_mp,      
           id_log_paso, 
           id_transaccion, 
           flag_aceptada_marca, 
           flag_conciliada, 
           flag_distribuida, 
           flag_contracargo,
           flag_notificado,
           fecha_alta,
           id_disputa,
           usuario_alta,
		   version
		   )
		VALUES(
		   @id_conciliacion,
		   @id_movimiento_mp,
		   @id_log_paso,
		   @id_transaccion,
		   0,
		   1,
		   0,
		   @flag_contracargo,
		   1,
		   GETDATE(),
		   0,
		   @usuario,
		   0
		   );


		-- Insertar en Conciliacion Manual --
		SELECT @id_conciliacion_manual = ISNULL(MAX(id_conciliacion_manual), 0) + 1
		FROM Configurations.dbo.Conciliacion_manual;

		INSERT INTO Configurations.dbo.Conciliacion_Manual (
			id_conciliacion_manual,
			id_transaccion,
			importe,
			moneda,
			cantidad_cuotas,
			nro_tarjeta,
			fecha_movimiento,
			nro_autorizacion,
			nro_cupon,
			nro_agrupador_boton,
			cargos_marca_por_movimiento,
			signo_cargos_marca_por_movimiento,
			fecha_pago,
			id_log_paso,
			fecha_alta,
			usuario_alta,
			flag_aceptada_marca,
			flag_contracargo,
			flag_conciliado_manual,
			flag_procesado,
			impuestos_boton_por_movimiento,
			cargos_boton_por_movimiento,
			id_movimiento_mp,
			version
			)
		VALUES (
			@id_conciliacion_manual,
			@id_transaccion,
			@importe,
			@moneda,
			@cantidad_cuotas,
			@nro_tarjeta,
			@fecha_movimiento,
			@nro_autorizacion,
			@nro_cupon,
			@nro_agrupador_boton,
			@cargos_marca_por_movimiento,
			@signo_cargos_marca_por_movimiento,
			@fecha_pago,
			@id_log_paso,
			GETDATE(),
			@usuario,
			0,
			@flag_contracargo,
			0,
			0,
			@TaxAmount,
			@FeeAmount,
			@id_movimiento_mp,
			0
			);

        -- Actualizar Conciliacion --
		UPDATE Configurations.dbo.Conciliacion 
        SET id_conciliacion_manual = @id_conciliacion_manual
        WHERE id_conciliacion = @id_conciliacion;

		COMMIT TRANSACTION;

		RETURN 1;
	END TRY

	BEGIN CATCH
		PRINT ERROR_MESSAGE();

		IF (@@TRANCOUNT > 0)
			ROLLBACK TRANSACTION;

		RETURN 0;
	END CATCH
END

GO
/****** Object:  StoredProcedure [dbo].[Batch_Concil_Movimientos_Conciliacion_Manual]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Concil_Movimientos_Conciliacion_Manual] (
	@flag_aceptada_marca BIT,
	@id_conciliacion_manual INT,
	@id_movimiento_mp INT,
	@usuario VARCHAR(20),
	@id_log_paso INT,
	@id_transaccion VARCHAR(36)
	)
AS

DECLARE @codigo_tipo VARCHAR(20);


BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRANSACTION;

		-- Obtener Codigo --
        SELECT
	      @codigo_tipo = tmp.codigo
        FROM
	      Configurations.dbo.Movimiento_Presentado_MP mpp 
	      INNER JOIN Configurations.dbo.Medio_De_Pago mdp 
		             ON mpp.id_medio_pago = mdp.id_medio_pago
	      INNER JOIN Configurations.dbo.Tipo_Medio_Pago tmp 
		             ON tmp.id_tipo_medio_pago = mdp.id_tipo_medio_pago
          WHERE mpp.id_movimiento_mp = @id_movimiento_mp


        -- Es aceptada o rechazada --
		IF(@flag_aceptada_marca = 1)
		   EXEC Configurations.dbo.Batch_Concil_Actualizar_Cupones
		        @id_transaccion,
				@id_log_paso,
				@usuario,
				@id_movimiento_mp,
				@codigo_tipo;
        ELSE
		   EXEC Configurations.dbo.Batch_Concil_Movimiento_Rechazado 
		        @id_movimiento_mp,
				@id_transaccion,
		        @id_log_paso,
				@usuario;

        -- Actualizar Conciliacion --
		UPDATE
		   Configurations.dbo.Conciliacion_Manual
        SET flag_procesado = 1
        WHERE id_conciliacion_manual = @id_conciliacion_manual;
		

		COMMIT TRANSACTION;

		RETURN 1;
	END TRY

	BEGIN CATCH
		PRINT ERROR_MESSAGE();

		IF (@@TRANCOUNT > 0)
			ROLLBACK TRANSACTION;

		RETURN 0;
	END CATCH
END
GO
/****** Object:  StoredProcedure [dbo].[Batch_Concil_Obtener_Cupones]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Concil_Obtener_Cupones]
AS
SET NOCOUNT ON;

DECLARE @msg VARCHAR(max);
DECLARE @i INT = 1;
DECLARE @count INT;
DECLARE @url VARCHAR(256);

BEGIN
	BEGIN TRY
		-- Limpiar tabla temporal
		TRUNCATE TABLE Configurations.dbo.Cupones_tmp;

		BEGIN TRANSACTION;

		-- Obtener URL del WebService
		SELECT @url = par.valor
		FROM Configurations.dbo.Parametro par
		WHERE par.codigo = 'URL_WS_NOTIF_PUSH';

		-- Obtener cupones a notificar.
		INSERT INTO Configurations.dbo.Cupones_tmp (
			id_conciliacion,
			id_transaccion,
			numero_cuenta,
			concepto,
			importe,
			e_mail,
			nombre_comprador,
			nombre_vendedor,
			url
			)
		SELECT id_conciliacion,
			id_transaccion,
			LocationIdentification,
			SaleConcept,
			Amount,
			CredentialEmailAddress,
			credentialholdername,
			CONCAT (
				cta.denominacion2,
				' ',
				cta.denominacion1
				),
			@url
		FROM Configurations.dbo.Conciliacion cln
		INNER JOIN Configurations.dbo.Movimiento_Presentado_MP mmp
			ON mmp.id_movimiento_mp = cln.id_movimiento_mp
		INNER JOIN Configurations.dbo.Medio_de_Pago mdp
			ON mmp.id_medio_pago = mdp.id_medio_pago
		INNER JOIN Transactions.dbo.transactions trn
			ON cln.id_transaccion = trn.Id
		INNER JOIN Configurations.dbo.Cuenta cta
			ON cta.id_cuenta = trn.LocationIdentification
		WHERE cln.flag_notificado = 0
			AND mdp.id_tipo_medio_pago = 3;

		COMMIT TRANSACTION;
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;

		SELECT @msg = ERROR_MESSAGE();

		THROW 51000,
			@Msg,
			1;
	END CATCH;

	RETURN 1;
END;

GO
/****** Object:  StoredProcedure [dbo].[Batch_Concil_Obtener_Dato_de_Log]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Concil_Obtener_Dato_de_Log]
(
   @id_log_paso INT,
   @usuario VARCHAR(20),
   @registros_aceptados INT = NULL OUTPUT,
   @importe_aceptados DECIMAL(12,2)= NULL OUTPUT,
   @registros_rechazados INT = NULL OUTPUT,
   @importe_rechazados DECIMAL(12,2) = NULL OUTPUT,
   @registros_salida INT = NULL OUTPUT,
   @importe_salida DECIMAL(12,2) = NULL OUTPUT,
   @resultado_proceso INT = 0 OUTPUT
)
AS 
DECLARE @msg VARCHAR(MAX)

BEGIN TRY 

SELECT
	@registros_aceptados = ISNULL(COUNT(*),0),
	@importe_aceptados = ISNULL(SUM(CASE WHEN RTRIM(LTRIM(mpm.signo_importe)) = '-' THEN (mpm.importe * -1)ELSE mpm.importe END),0)
FROM
	dbo.Conciliacion cln 
	INNER JOIN
	dbo.Movimiento_Presentado_MP mpm 
	ON cln.id_movimiento_mp = mpm.id_movimiento_mp
WHERE cln.flag_conciliada = 1
	AND cln.flag_aceptada_marca = 1
	AND cln.id_log_paso = @id_log_paso

SELECT
	@registros_rechazados = SUM(R.cantidad),
	@importe_rechazados = ISNULL(SUM(R.importe), 0)
FROM(
	SELECT
		COUNT(*) AS cantidad,
		SUM(CASE WHEN RTRIM(LTRIM(mpm.signo_importe)) = '-' THEN (mpm.importe * -1)ELSE mpm.importe END) as importe
	FROM
		dbo.Conciliacion cln 
		INNER JOIN
		dbo.Movimiento_Presentado_MP mpm 
		ON cln.id_movimiento_mp = mpm.id_movimiento_mp
	WHERE cln.flag_conciliada = 1
	  AND cln.flag_aceptada_marca = 0
	  AND cln.id_log_paso = @id_log_paso
	UNION ALL
	SELECT
		COUNT(*) AS cantidad,
		SUM(CASE WHEN RTRIM(LTRIM(mad.signo_importe)) = '-' THEN (mad.importe * -1)ELSE mad.importe END) as importe
	FROM dbo.Movimientos_a_distribuir mad
	WHERE mad.tipo = 'N'
	  AND mad.id_log_paso = @id_log_paso
) R


SET @registros_salida =  @registros_rechazados + @registros_aceptados;
SET @importe_salida = @importe_rechazados + @importe_aceptados;
SET @resultado_proceso = 1;

EXEC Configurations.dbo.Finalizar_Log_Paso_Proceso	
    @id_log_paso, 
	NULL, 
	@resultado_proceso,
	NULL,
	0,
	0,
	@registros_aceptados,
	@importe_aceptados,
	@registros_rechazados,
	@importe_rechazados,
	@registros_salida,
	@importe_salida,
	@usuario;

END TRY

BEGIN CATCH
    IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;

	SELECT @msg = ERROR_MESSAGE();

	THROW 51000,
		@msg,
		1;
END CATCH;



GO
/****** Object:  StoredProcedure [dbo].[Batch_Concil_Obtener_Movimientos_A_Distribuir]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Concil_Obtener_Movimientos_A_Distribuir] (
	@id_log_paso INT,
	@usuario VARCHAR(20)
	)
AS
DECLARE @distribuidas TABLE (id_transaccion VARCHAR(36));

BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRANSACTION;

		-- Obtener Conciliaciones no Distribuidas
		INSERT INTO Configurations.dbo.Movimientos_a_distribuir (
			id_transaccion,
			id_medio_pago,
			id_cuenta,
			BCRA_cuenta,
			BCRA_emisor_tarjeta,
			signo_importe,
			importe,
			signo_cargo_marca,
			cargo_marca,
			signo_cargo_boton,
			cargo_boton,
			signo_impuesto_boton,
			impuesto_boton,
			fecha_liberacion_cashout,
			id_log_paso,
			tipo,
			flag_esperando_impuestos_generales_de_marca,
			usuario_alta,
			id_movimiento_mp,
			fecha_alta,
			version
			)
		OUTPUT inserted.id_transaccion
		INTO @distribuidas
		SELECT trn.Id,
			trn.ProductIdentification,
			trn.LocationIdentification,
			cast(isnull(left(ibc.cbu_cuenta_banco, 4), '0') AS INT),
			0,
			mpm.signo_importe,
			mpm.importe,
			'+',
			mpm.cargos_marca_por_movimiento,
			'+',
			isnull(trn.FeeAmount, 0),
			'+',
			isnull(trn.TaxAmount, 0),
			trn.CashoutTimestamp,
			@id_log_paso,
			'C',
			0,
			@usuario,
			mpm.id_movimiento_mp,
			getdate(),
			0
		FROM Configurations.dbo.Conciliacion con
		INNER JOIN Configurations.dbo.Movimiento_Presentado_MP mpm
			ON con.id_movimiento_mp = mpm.id_movimiento_mp
		INNER JOIN Transactions.dbo.transactions trn
			ON con.id_transaccion = trn.Id
		LEFT JOIN Configurations.dbo.Informacion_Bancaria_Cuenta ibc
			ON trn.LocationIdentification = ibc.id_cuenta
			AND (
				ibc.flag_vigente = 1
				OR (
					ibc.flag_vigente = 0
					AND ibc.fecha_baja IS NULL
					AND ibc.fecha_alta = (
						SELECT max(ibc1.fecha_alta)
						FROM Configurations.dbo.Informacion_Bancaria_Cuenta ibc1
						WHERE ibc1.id_cuenta = trn.LocationIdentification
							AND ibc1.flag_vigente = 0
						)
					)
				)
		WHERE con.flag_distribuida = 0
			AND con.flag_conciliada = 1
			AND con.flag_aceptada_marca = 1;

		-- Actualizar las distribuidas
		UPDATE Configurations.dbo.Conciliacion
		SET flag_distribuida = 1
		WHERE id_transaccion IN (
				SELECT id_transaccion
				FROM @distribuidas
				);

		COMMIT TRANSACTION;

		RETURN 1;
	END TRY

	BEGIN CATCH
		PRINT ERROR_MESSAGE();

		IF (@@TRANCOUNT > 0)
			ROLLBACK TRANSACTION;

		RETURN 0;
	END CATCH
END

GO
/****** Object:  StoredProcedure [dbo].[Batch_Concil_Resultado_WScontracargo]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Concil_Resultado_WScontracargo] (
    @usuario VARCHAR(20),
	@id_log_paso INT,
	@id_disputa VARCHAR(20),
	@codigo VARCHAR(20),
	@id_movimiento_mp INT,
	@id_conciliacion INT
	)
AS
 
DECLARE @CodigoAux VARCHAR(6);
DECLARE @id_conciliacion_manual INT = NULL;
DECLARE @importe DECIMAL(12, 2) = NULL;
DECLARE	@moneda INT = NULL;
DECLARE @cantidad_cuotas INT = NULL;
DECLARE	@nro_tarjeta VARCHAR(50) = NULL;
DECLARE	@fecha_movimiento DATETIME = NULL;
DECLARE	@nro_autorizacion VARCHAR(50) = NULL;
DECLARE	@nro_cupon VARCHAR(50) = NULL;
DECLARE	@nro_agrupador_boton VARCHAR(50) = NULL;
DECLARE @id_transaccion VARCHAR(40) = NULL;
DECLARE	@flag_aceptada_marca BIT = NULL;
DECLARE	@fecha_pago DATETIME = NULL;
DECLARE	@cargos_marca_por_movimiento DECIMAL(12, 2) = NULL;
DECLARE	@signo_cargos_marca_por_movimiento VARCHAR(1) = NULL
DECLARE @cargos_boton_por_movimiento DECIMAL(12, 2) = NULL;
DECLARE @impuestos_boton_por_movimiento DECIMAL(12, 2) = NULL;

BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRANSACTION;

		SET @CodigoAux = RIGHT(@codigo, 5);

		IF(@CodigoAux = '00000')
		   BEGIN
		     UPDATE configurations.dbo.conciliacion 
             SET id_disputa = @id_disputa
             WHERE id_conciliacion = @id_conciliacion;
		   END;
		ELSE IF(@CodigoAux <> '10001' AND
		        @CodigoAux <> '10002' AND
				@CodigoAux <> '10003' AND
				@CodigoAux <> '10004' AND
				@CodigoAux <> '10005' AND
				@CodigoAux <> '10202' AND
				@CodigoAux <> '10206' AND
				NOT EXISTS(SELECT 1 
				           FROM Configurations.dbo.Conciliacion_Manual 
						   WHERE id_transaccion = @id_transaccion
						   )
				)
           BEGIN

		     SELECT 
			    @id_conciliacion_manual = ISNULL(MAX([id_conciliacion_manual]), 0) + 1
		     FROM Configurations.dbo.Conciliacion_manual;

			 SELECT 
	            @importe = mp.importe, 
                @moneda = mp.moneda, 
                @cantidad_cuotas = mp.cantidad_cuotas, 
                @nro_tarjeta = mp.nro_tarjeta, 
                @fecha_movimiento = mp.fecha_movimiento, 
                @nro_autorizacion = mp.nro_autorizacion, 
                @nro_cupon = mp.nro_cupon, 
                @nro_agrupador_boton = mp.nro_agrupador_boton,
                @fecha_pago = mp.fecha_pago,
                @cargos_marca_por_movimiento = mp.cargos_marca_por_movimiento,
                @signo_cargos_marca_por_movimiento = mp.signo_cargos_marca_por_movimiento,
                @id_transaccion = c.id_transaccion, 
                @flag_aceptada_marca = c.flag_aceptada_marca,
				@cargos_boton_por_movimiento = t.FeeAmount,
				@impuestos_boton_por_movimiento = t.TaxAmount
            FROM Configurations.dbo.Movimiento_presentado_mp mp
            INNER JOIN Configurations.dbo.Conciliacion c ON c.id_movimiento_mp = mp.id_movimiento_mp
			INNER JOIN Transactions.dbo.transactions t ON t.Id = c.id_transaccion
            WHERE mp.id_movimiento_mp = @id_movimiento_mp;

		   INSERT INTO Configurations.dbo.Conciliacion_Manual (
			  id_conciliacion_manual,
			  id_transaccion,
			  importe,
			  moneda,
			  cantidad_cuotas,
			  nro_tarjeta,
			  fecha_movimiento,
			  nro_autorizacion,
			  nro_cupon,
			  nro_agrupador_boton,
			  cargos_marca_por_movimiento,
			  signo_cargos_marca_por_movimiento,
			  fecha_pago,
			  id_log_paso,
			  fecha_alta,
			  usuario_alta,
			  flag_aceptada_marca,
			  flag_contracargo,
			  flag_conciliado_manual,
			  flag_procesado,
			  impuestos_boton_por_movimiento,
			  cargos_boton_por_movimiento,
			  id_movimiento_mp,
			  version
			 )
		  VALUES (
			  @id_conciliacion_manual,
			  @id_transaccion,
			  @importe,
			  @moneda,
			  @cantidad_cuotas,
			  @nro_tarjeta,
			  @fecha_movimiento,
			  @nro_autorizacion,
			  @nro_cupon,
			  @nro_agrupador_boton,
			  @cargos_marca_por_movimiento,
			  @signo_cargos_marca_por_movimiento,
			  @fecha_pago,
			  @id_log_paso,
			  GETDATE(),
			  @usuario,
			  0,
			  0,
			  0,
			  0,
			  @impuestos_boton_por_movimiento,
			  @cargos_boton_por_movimiento,
			  @id_movimiento_mp,
			  0
			  );

		   END


		COMMIT TRANSACTION;

		RETURN 1;
	END TRY

	BEGIN CATCH
		PRINT ERROR_MESSAGE();

		IF (@@TRANCOUNT > 0)
			ROLLBACK TRANSACTION;

		RETURN 0;
	END CATCH
END

GO
/****** Object:  StoredProcedure [dbo].[Batch_Liq_Actualizar_Acumulador_Promociones]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Liq_Actualizar_Acumulador_Promociones] (
 @CreateTimestamp DATETIME
 ,@LocationIdentification INT
 ,@Amount DECIMAL(12, 2)
 ,@PromotionIdentification INT
 ,@FlagDev INT
 )
AS
DECLARE @ret_code INT;
DECLARE @cantidad_tx INT = 1;

BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  MERGE Configurations.dbo.Acumulador_Promociones AS destino
  USING (
   SELECT rbn.id_promocion AS id_promocion
    ,@CreateTimestamp AS fecha_transaccion
    ,@LocationIdentification AS cuenta_transaccion
    ,@Amount AS importe_total_tx
    ,@cantidad_tx AS cantidad_tx
   FROM Configurations.dbo.Regla_Bonificacion rbn
   WHERE rbn.id_regla_bonificacion = @PromotionIdentification
   ) AS origen(id_promocion, fecha_transaccion, cuenta_transaccion, importe_total_tx, cantidad_tx)
   ON (
     destino.id_promocion = origen.id_promocion
     AND CAST(destino.fecha_transaccion AS DATE) = CAST(origen.fecha_transaccion AS DATE)
     AND destino.cuenta_transaccion = origen.cuenta_transaccion
     )
  WHEN MATCHED
   THEN
    UPDATE
    SET destino.importe_total_tx = destino.importe_total_tx + IIF(@FlagDev = 1, @Amount * - 1, @Amount)
     ,destino.cantidad_tx = destino.cantidad_tx + 1
  WHEN NOT MATCHED
   THEN
    INSERT (
     id_promocion
     ,fecha_transaccion
     ,cuenta_transaccion
     ,importe_total_tx
     ,cantidad_tx
     )
    VALUES (
     origen.id_promocion
     ,origen.fecha_transaccion
     ,origen.cuenta_transaccion
     ,origen.importe_total_tx
     ,origen.cantidad_tx
     );

  SET @ret_code = 1;
 END TRY

 BEGIN CATCH
  PRINT ERROR_MESSAGE();

  SET @ret_code = 0;
 END CATCH

 RETURN @ret_code;
END

GO
/****** Object:  StoredProcedure [dbo].[Batch_Liq_Calcular_Cargos]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    
CREATE PROCEDURE [dbo].[Batch_Liq_Calcular_Cargos] (    
 @Id CHAR(36)    
 ,@CreateTimestamp DATETIME    
 ,@LocationIdentification INT    
 ,@ProductIdentification INT    
 ,@Amount DECIMAL(12, 2)    
 ,@PromotionIdentification INT    
 ,@FacilitiesPayments INT    
 ,@ButtonCode VARCHAR(20)    
 ,@Usuario VARCHAR(20)    
 ,@FeeAmount DECIMAL(12, 2) OUTPUT    
 )    
AS    
DECLARE @id_base_de_calculo INT;    
DECLARE @Cargos TABLE (    
 id INT PRIMARY KEY IDENTITY(1, 1)    
 ,id_cargo INT    
 ,monto_calculado DECIMAL(12, 2)    
 ,valor_aplicado DECIMAL(12, 2)    
 ,id_tipo_aplicacion INT    
 ,codigo_aplicacion VARCHAR(20)    
 ,codigo_tipo_cargo VARCHAR(20)    
 );    
DECLARE @i INT;    
DECLARE @cargos_count INT;    
DECLARE @id_cargo INT;    
DECLARE @codigo_tipo_cargo VARCHAR(20);    
DECLARE @valor_aplicado DECIMAL(12, 2);    
DECLARE @id_tipo_aplicacion INT;    
DECLARE @codigo_aplicacion VARCHAR(20);    
DECLARE @bonificacion_cf_vendedor DECIMAL(5, 2);    
DECLARE @tasa_directa DECIMAL(5, 2);    
DECLARE @ret_code INT;    
DECLARE @monto_total_tx DECIMAL(12, 2);    
DECLARE @codigo_tipo_promocion VARCHAR(20);    
DECLARE @id_promocion INT;    
    
BEGIN    
 SET NOCOUNT ON;    
    
 BEGIN TRY    
  IF (@ButtonCode = 'CPTO_BTN_AJ_CTGO')    
   SET @FeeAmount = 0;    
  ELSE    
  BEGIN    
   SELECT @id_base_de_calculo = tpo.id_tipo    
   FROM Configurations.dbo.Tipo tpo    
   WHERE tpo.Codigo = (    
     CASE     
      WHEN @FacilitiesPayments = 1    
       THEN 'BC_TX_PAGO'    
      ELSE 'BC_TX_CUOTAS'    
      END    
     );    
    
   INSERT INTO @Cargos (    
    id_cargo    
    ,monto_calculado    
    ,valor_aplicado    
    ,id_tipo_aplicacion    
    ,codigo_aplicacion    
    ,codigo_tipo_cargo    
    )    
   SELECT cgo.id_cargo    
    ,0    
    ,cgo.valor    
    ,tpo.id_tipo    
    ,tpo.codigo    
    ,tcg.codigo    
   FROM Configurations.dbo.Cargo cgo    
    ,Configurations.dbo.Medio_De_Pago mdp    
    ,Configurations.dbo.Cuenta cta    
    ,Configurations.dbo.Tipo tpo    
    ,Configurations.dbo.Tipo_Cargo tcg    
   WHERE cgo.id_tipo_medio_pago = mdp.id_tipo_medio_pago    
    AND mdp.id_medio_pago = @ProductIdentification    
    AND cgo.id_tipo_cuenta = cta.id_tipo_cuenta    
    AND cta.id_cuenta = @LocationIdentification    
    AND cgo.id_tipo_aplicacion = tpo.id_tipo    
    AND cgo.flag_estado = 1    
    AND cgo.id_tipo_cargo = tcg.id_tipo_cargo    
    AND cgo.id_base_de_calculo = @id_base_de_calculo    
    AND tcg.id_tipo_cargo = 1    
       
   UNION    
       
   SELECT cgo.id_cargo    
    ,0    
    ,cgo.valor    
    ,NULL    
    ,NULL    
    ,tcg.codigo    
   FROM Configurations.dbo.Cargo cgo    
    ,Configurations.dbo.Medio_De_Pago mdp    
    ,Configurations.dbo.Cuenta cta    
    ,Configurations.dbo.Tipo_Cargo tcg    
   WHERE cgo.id_tipo_medio_pago = mdp.id_tipo_medio_pago    
    AND mdp.id_medio_pago = @ProductIdentification    
    AND cgo.id_tipo_cuenta = cta.id_tipo_cuenta    
    AND cta.id_cuenta = @LocationIdentification    
    AND cgo.flag_estado = 1    
    AND cgo.id_tipo_cargo = tcg.id_tipo_cargo    
    AND cgo.id_base_de_calculo = @id_base_de_calculo    
    AND tcg.id_tipo_cargo = 2    
    
   SET @i = 1;    
    
   SELECT @cargos_count = COUNT(*)    
   FROM @Cargos;    
    
   WHILE (@i <= @cargos_count)    
   BEGIN    
    SELECT @id_cargo = id_cargo    
     ,@codigo_tipo_cargo = codigo_tipo_cargo    
    FROM @Cargos    
    WHERE id = @i;    
    
    IF (@codigo_tipo_cargo = 'COMISION')    
    BEGIN    
     SELECT @valor_aplicado = cca.valor    
      ,@id_tipo_aplicacion = cca.id_tipo_aplicacion    
      ,@codigo_aplicacion = tpo.codigo    
     FROM Configurations.dbo.Cargo_Cuenta cca    
      ,Configurations.dbo.Tipo tpo    
     WHERE cca.id_tipo_aplicacion = tpo.id_tipo    
      AND cca.id_cargo = @id_cargo    
      AND cca.id_cuenta = @LocationIdentification    
      AND CAST(cca.fecha_inicio_vigencia AS DATE) <= CAST(@CreateTimestamp AS DATE)    
      AND (    
       cca.fecha_fin_vigencia IS NULL    
       OR CAST(cca.fecha_fin_vigencia AS DATE) >= CAST(@CreateTimestamp AS DATE)    
       );    
    
     IF (@valor_aplicado IS NOT NULL)    
      UPDATE @Cargos    
      SET valor_aplicado = @valor_aplicado    
       ,id_tipo_aplicacion = @id_tipo_aplicacion    
       ,codigo_aplicacion = @codigo_aplicacion        WHERE Id = @i;    
    
     SELECT @valor_aplicado = cgo.valor_aplicado    
      ,@codigo_aplicacion = cgo.codigo_aplicacion    
     FROM @Cargos cgo    
     WHERE id = @i;        
    
     UPDATE @Cargos    
     SET monto_calculado = (    
       CASE     
        WHEN @codigo_aplicacion = 'AP_PORCENTAJE'    
         THEN @Amount * (@valor_aplicado / 100)    
		WHEN @codigo_aplicacion = 'AP_FIJO'   
		 THEN @valor_aplicado
        ELSE 0    
        END    
       )    
     WHERE id = @i;    
    END    
    
    IF (@codigo_tipo_cargo = 'COSTO_FIN_V')    
    BEGIN --1          
     SELECT @bonificacion_cf_vendedor = rbn.bonificacion_cf_vendedor    
      ,@tasa_directa = tmp.tasa_directa    
      ,@codigo_tipo_promocion = tpo.codigo    
      ,@id_promocion = pmn.id_promocion    
     FROM Configurations.dbo.Regla_Bonificacion rbn    
      ,Configurations.dbo.Tasa_MP tmp    
      ,Configurations.dbo.Promocion pmn    
      ,Configurations.dbo.Tipo tpo    
     WHERE rbn.id_tasa_mp = tmp.id_tasa_mp    
      AND rbn.id_regla_bonificacion = @PromotionIdentification    
      AND rbn.id_promocion = pmn.id_promocion    
      AND pmn.id_tipo_aplicacion = tpo.id_tipo    
      AND tpo.id_grupo_tipo = 25;    
    
     IF (    
       @PromotionIdentification IS NULL    
       OR @bonificacion_cf_vendedor = 100    
       )    
     BEGIN --2          
      UPDATE @Cargos    
      SET monto_calculado = 0    
       ,valor_aplicado = 0    
      WHERE id = @i;    
     END --2               
     ELSE IF (@bonificacion_cf_vendedor IS NULL)    
     BEGIN --3                
      IF (@codigo_tipo_promocion = 'PROMO_VTA_MES_CTA')    
      BEGIN --4          
       SELECT @monto_total_tx = ISNULL(SUM(aps.importe_total_tx), 0)    
       FROM Configurations.dbo.Acumulador_Promociones aps    
       WHERE CAST(aps.fecha_transaccion AS DATE) >= DATEADD(month, DATEDIFF(month, 0, CAST(@CreateTimestamp AS DATE)), 0)    
        AND CAST(aps.fecha_transaccion AS DATE) <= CAST(@CreateTimestamp AS DATE)    
        AND aps.cuenta_transaccion = @LocationIdentification    
        AND aps.id_promocion = @id_promocion    
      END --4          
      ELSE IF (@codigo_tipo_promocion = 'PROMO_VTA_TOTAL_CTA')    
      BEGIN --5          
       SELECT @monto_total_tx = ISNULL(SUM(aps.importe_total_tx), 0)    
       FROM Configurations.dbo.Acumulador_Promociones aps    
       WHERE aps.cuenta_transaccion = @LocationIdentification    
        AND aps.id_promocion = @id_promocion    
      END --5          
      ELSE IF (@codigo_tipo_promocion = 'PROMO_VTA_TOTAL')    
      BEGIN --6                 
       SELECT @monto_total_tx = ISNULL(SUM(aps.importe_total_tx), 0)    
       FROM Configurations.dbo.Acumulador_Promociones aps    
       WHERE aps.id_promocion = @id_promocion;    
      END --6              
    
      SELECT @bonificacion_cf_vendedor = v.bonificacion_cf_vendedor    
       ,@tasa_directa = tmp.tasa_directa    
      FROM Configurations.dbo.Regla_Bonificacion rb    
      INNER JOIN Configurations.dbo.Regla_Promocion rp ON rb.id_regla_promocion = rp.id_regla_promocion    
      INNER JOIN Configurations.dbo.Volumen_Regla_Promocion v ON rp.id_regla_promocion = v.id_regla_promocion    
      INNER JOIN Configurations.dbo.Tasa_MP tmp ON rb.id_tasa_mp = tmp.id_tasa_mp    
      WHERE rb.id_regla_bonificacion = @PromotionIdentification    
       AND v.volumen_vta_desde <= @monto_total_tx    
       AND (    
     v.volumen_vta_hasta IS NULL    
        OR v.volumen_vta_hasta >= @monto_total_tx    
        );        
    
      UPDATE @Cargos    
      SET monto_calculado = CAST(@Amount * (@tasa_directa / 100) * ((100 - ISNULL(@bonificacion_cf_vendedor, 0)) / 100) AS DECIMAL(12, 2))    
       ,valor_aplicado = IIF(@bonificacion_cf_vendedor IS NULL, 0, 100 - @bonificacion_cf_vendedor)    
      WHERE id = @i;    
     END --3         
     ELSE IF (    
       @bonificacion_cf_vendedor IS NOT NULL    
       AND @bonificacion_cf_vendedor <> 100    
       AND @codigo_tipo_promocion = 'PROMO_CTAS'    
       )    
     BEGIN --7             
      UPDATE @Cargos    
      SET monto_calculado = CAST(@Amount * (@tasa_directa / 100) * ((100 - ISNULL(@bonificacion_cf_vendedor, 0)) / 100) AS DECIMAL(12, 2))    
       ,valor_aplicado = IIF(@bonificacion_cf_vendedor IS NULL, 0, 100 - @bonificacion_cf_vendedor)    
      WHERE id = @i;    
     END --7        
    END --1          
    
    INSERT INTO Configurations.dbo.Cargos_Por_Transaccion (    
     id_cargo    
     ,id_transaccion    
     ,monto_calculado    
     ,valor_aplicado    
     ,id_tipo_aplicacion    
     ,fecha_alta    
     ,usuario_alta    
     ,version    
     )    
    SELECT id_cargo    
     ,@Id    
     ,monto_calculado    
     ,valor_aplicado    
     ,id_tipo_aplicacion    
     ,GETDATE()    
     ,@Usuario    
     ,0    
    FROM @Cargos    
    WHERE id = @i;    
    
    SET @i += 1;    
   END    
    
   SELECT @FeeAmount = ISNULL(SUM(monto_calculado), 0)    
   FROM @Cargos;    
  END    
    
  SET @ret_code = 1;    
 END TRY    
    
 BEGIN CATCH    
  SET @ret_code = 0;    
    
  PRINT ERROR_MESSAGE();    
 END CATCH    
    
 RETURN @ret_code;    
END

GO
/****** Object:  StoredProcedure [dbo].[Batch_Liq_Calcular_Fecha_Cashout]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Liq_Calcular_Fecha_Cashout] (
	@CreateTimestamp DATETIME,
	@LocationIdentification INT,           
	@ProductIdentification INT,          
	@FacilitiesPayments INT,
	@PaymentTimestamp DATETIME,
	@CashoutTimestamp DATETIME OUTPUT      
)          
AS
	DECLARE @tmp_codigo VARCHAR(20);
	DECLARE @plazo_liberacion INT;
	DECLARE @plazo_liberacion_cuotas INT;
	DECLARE @plazo INT;
	DECLARE @fecha_desde DATETIME;
BEGIN          
	SET NOCOUNT ON;          

	BEGIN TRY
		SELECT
			@tmp_codigo = tmp.codigo,
			@plazo_liberacion = pln.plazo_liberacion,
			@plazo_liberacion_cuotas = pln.plazo_liberacion_cuotas
		FROM
			Configurations.dbo.Plazo_Liberacion pln,
			Configurations.dbo.Medio_De_Pago mdp,
			Configurations.dbo.Tipo_Medio_Pago tmp
		WHERE mdp.flag_habilitado > 0
		  AND mdp.id_tipo_medio_pago = tmp.id_tipo_medio_pago
		  AND tmp.id_tipo_medio_pago = pln.id_tipo_medio_pago
		  AND pln.id_cuenta = @LocationIdentification
		  AND mdp.id_medio_pago = @ProductIdentification
		  AND GETDATE() >= pln.fecha_alta
		  AND (
			pln.fecha_baja IS NULL
			OR
			GETDATE() <= pln.fecha_baja
		  );

		IF (@tmp_codigo IS NULL)
			SELECT
				@tmp_codigo = tmp.codigo,
				@plazo_liberacion = pln.plazo_liberacion,
				@plazo_liberacion_cuotas = pln.plazo_liberacion_cuotas
			FROM
				Configurations.dbo.Cuenta cta,
				Configurations.dbo.Actividad_Cuenta aca,
				Configurations.dbo.Medio_De_Pago mdp,
				Configurations.dbo.Tipo_Medio_Pago tmp,
				Configurations.dbo.Plazo_Liberacion pln
			WHERE cta.id_tipo_cuenta = pln.id_tipo_cuenta
			  AND cta.id_cuenta = aca.id_cuenta
			  AND aca.id_rubro = pln.id_rubro
			  AND mdp.flag_habilitado > 0
			  AND mdp.id_tipo_medio_pago = tmp.id_tipo_medio_pago
			  AND tmp.id_tipo_medio_pago = pln.id_tipo_medio_pago
			  AND cta.id_cuenta = @LocationIdentification
			  AND mdp.id_medio_pago = @ProductIdentification
			  AND GETDATE() >= pln.fecha_alta
			  AND (
				pln.fecha_baja IS NULL
				OR
				GETDATE() <= pln.fecha_baja
			  );

		IF (@tmp_codigo IS NULL)
			SELECT
				@tmp_codigo = tmp.codigo,
				@plazo_liberacion = pln.plazo_liberacion,
				@plazo_liberacion_cuotas = pln.plazo_liberacion_cuotas
			FROM
				Configurations.dbo.Cuenta cta,
				Configurations.dbo.Medio_De_Pago mdp,
				Configurations.dbo.Tipo_Medio_Pago tmp,
				Configurations.dbo.Plazo_Liberacion pln
			WHERE cta.id_tipo_cuenta = pln.id_tipo_cuenta
			  AND mdp.flag_habilitado > 0
			  AND mdp.id_tipo_medio_pago = tmp.id_tipo_medio_pago
			  AND tmp.id_tipo_medio_pago = pln.id_tipo_medio_pago
			  AND pln.id_cuenta IS NULL
			  AND cta.id_cuenta = @LocationIdentification
			  AND mdp.id_medio_pago = @ProductIdentification
			  AND GETDATE() >= pln.fecha_alta
			  AND (
				pln.fecha_baja IS NULL
				OR
				GETDATE() <= pln.fecha_baja
			  );


		IF (@FacilitiesPayments = 1)
			SET @plazo = @plazo_liberacion;
		ELSE
			SET @plazo = @plazo_liberacion_cuotas;

		IF (@tmp_codigo = 'EFECTIVO')
			SET @fecha_desde = @PaymentTimestamp;
		ELSE
			SET @fecha_desde = @CreateTimestamp;

		WITH Dias_Habiles(dia_habil, nro_fila) AS (
			SELECT
				CAST(fro.fecha AS DATE) AS dia_habil,
				ROW_NUMBER() OVER (ORDER BY fro.fecha) AS nro_fila 
			FROM Configurations.dbo.Feriados fro
			WHERE fro.esFeriado = 0
			  AND fro.habilitado = 1
		)
		SELECT 
			@CashoutTimestamp = DATETIMEFROMPARTS (
				DATEPART(yyyy, dia_habil), DATEPART(mm, dia_habil), DATEPART(dd, dia_habil),
				DATEPART(hh, @fecha_desde), DATEPART(mi, @fecha_desde), DATEPART(ss, @fecha_desde), DATEPART(ms, @fecha_desde)
			)
		FROM Dias_Habiles
		WHERE nro_fila = (
			SELECT TOP 1 nro_fila + @plazo
			FROM Dias_Habiles
			WHERE dia_habil <= CAST(@fecha_desde AS DATE)
			ORDER BY dia_habil DESC
		);

		RETURN 1;        
	END TRY        

	BEGIN CATCH        
		RETURN 0;    
	END CATCH        
END
GO
/****** Object:  StoredProcedure [dbo].[Batch_Liq_Calcular_Fecha_Tope_Presentacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Liq_Calcular_Fecha_Tope_Presentacion] (
	@ProductIdentification INT,
	@CreateTimestamp DATETIME,         
	@FilingDeadline DATETIME OUTPUT      
)          
AS
	DECLARE @plazo_pago_marca INT;
	DECLARE @margen_espera_pago_marca INT;
	DECLARE @dias INT;
BEGIN          
	SET NOCOUNT ON;          

	BEGIN TRY
		SELECT 
			@plazo_pago_marca = mdp.plazo_pago_marca,
			@margen_espera_pago_marca = mdp.margen_espera_pago_marca
		FROM Configurations.dbo.Medio_De_Pago mdp
		WHERE mdp.flag_habilitado > 0
		  AND mdp.id_medio_pago = @ProductIdentification;

		SET @dias = ISNULL(@plazo_pago_marca, 0) + ISNULL(@margen_espera_pago_marca, 0);
		SET @FilingDeadline = DATEADD(dd, @dias, @CreateTimestamp);

		RETURN 1;        
	END TRY        

	BEGIN CATCH        
		RETURN 0;    
	END CATCH        
END
GO
/****** Object:  StoredProcedure [dbo].[Batch_Liq_Calcular_Impuestos]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
    
CREATE PROCEDURE [dbo].[Batch_Liq_Calcular_Impuestos] (    
 @Id CHAR(36)    
 ,@CreateTimestamp DATETIME    
 ,@LocationIdentification INT    
 ,@Usuario VARCHAR(20)    
 ,@TaxAmount DECIMAL(12, 2) OUTPUT    
 )    
AS    
--Tabla temp.para Cargos_Por_Transaccion    
DECLARE @Cargos_Por_Transaccion TABLE (    
 id_cargo_trasaccion INT PRIMARY KEY IDENTITY(1, 1)    
 ,id_cargo INT    
 ,monto_calculado DECIMAL(12, 2)    
 );    
--Tabla temp.para Impuestos_Por_Cuenta    
DECLARE @Impuestos_Por_Cta TABLE (    
 id_impuesto_por_cta INT PRIMARY KEY IDENTITY(1, 1)    
 ,numero_CUIT VARCHAR(11)    
 ,razon_social VARCHAR(50)    
 ,id_domicilio_facturacion INT    
 ,id_tipo_condicion_IVA INT    
 ,fecha_hasta_exclusion_IVA DATETIME    
 ,porcentaje_exclusion_iva DECIMAL(5, 2)    
 ,id_tipo_condicion_IIBB INT    
 ,fecha_hasta_exclusion_IIBB DATETIME    
 ,porcentaje_exclusion_IIBB DECIMAL(5, 2)    
 ,id_impuesto INT    
 ,tipo_impuesto VARCHAR(20)    
 );    
--Tabla temp.para Impuesto_Por_Transaccion         
DECLARE @Impuestos_Por_TX TABLE (    
 id_impuesto_por_transaccion INT PRIMARY KEY IDENTITY(1, 1)    
 ,id_cargo INT    
 ,id_impuesto INT    
 ,monto_calculado DECIMAL(12, 2)    
 ,alicuota DECIMAL(12, 2)    
 );    
DECLARE @i INT;    
DECLARE @j INT;    
DECLARE @impuestos_count INT;    
DECLARE @cargos_count INT;    
DECLARE @tipo_impuesto VARCHAR(20);    
DECLARE @monto_calculado_cargo DECIMAL(12, 2);    
DECLARE @monto_calculado_impuesto DECIMAL(12, 2);    
DECLARE @alicuota DECIMAL(12, 2);    
DECLARE @id_cargo INT;    
DECLARE @id_impuesto INT;    
DECLARE @id_tipo_condicion_IVA INT;    
DECLARE @ret_code INT = 1;--sin errores    
    
BEGIN    
 SET NOCOUNT ON;    
    
 BEGIN TRY    
  --Obtener cargos por transaccion    
  INSERT INTO @Cargos_Por_Transaccion (    
   id_cargo    
   ,monto_calculado    
   )    
  SELECT cpn.id_cargo    
   ,cpn.monto_calculado --valor cargo    
  FROM Configurations.dbo.Cargos_Por_Transaccion cpn    
  WHERE cpn.id_transaccion = @Id;    
    
  --Obtener impuestos de la cuenta    
  INSERT INTO @Impuestos_Por_Cta (    
   numero_CUIT    
   ,razon_social    
   ,id_domicilio_facturacion    
   ,id_tipo_condicion_IVA    
   ,fecha_hasta_exclusion_IVA    
   ,porcentaje_exclusion_iva    
   ,id_tipo_condicion_IIBB    
   ,fecha_hasta_exclusion_IIBB    
   ,porcentaje_exclusion_IIBB    
   ,id_impuesto    
   ,tipo_impuesto    
   )    
  --Obtener tipos de impuesto por cuenta    
  SELECT sfc.numero_CUIT AS numeroCUIT    
   ,sfc.razon_social AS razonSocial    
   ,sfc.id_domicilio_facturacion AS idDomicilioFacturacion    
   ,sfc.id_tipo_condicion_IVA AS idTipoCondicionIVA    
   ,sfc.fecha_hasta_exclusion_IVA AS fechaHastaExclusionIVA    
   ,sfc.porcentaje_exclusion_iva AS porcentajeExclusionIVA    
   ,sfc.id_tipo_condicion_IIBB AS idTipoCondicionIIBB    
   ,sfc.fecha_hasta_exclusion_IIBB AS fechaHastaExclusionIIBB    
   ,sfc.porcentaje_exclusion_IIBB AS porcentajeExclusionIIBB    
   ,ipo.id_impuesto AS idImpuesto    
   ,ipo.codigo AS tipoImpuesto    
  FROM Configurations.dbo.Impuesto AS ipo    
   ,Configurations.dbo.Situacion_Fiscal_Cuenta AS sfc    
  INNER JOIN Configurations.dbo.Domicilio_Cuenta AS dca ON sfc.id_cuenta = dca.id_cuenta    
   AND sfc.id_domicilio_facturacion = dca.id_domicilio    
  WHERE sfc.id_cuenta = @LocationIdentification    
   AND sfc.flag_vigente = 1    
   AND (    
    ipo.id_provincia = dca.id_provincia    
    OR ipo.flag_todas_provincias = 1    
    );    
    
  SET @impuestos_count = (    
    SELECT COUNT(*)    
    FROM @Impuestos_Por_Cta    
    );    
  SET @cargos_count = (    
    SELECT COUNT(*)    
    FROM @Cargos_Por_Transaccion    
    );    
  SET @i = 1;    
    
  --Iterar cada cargo    
  WHILE (@i <= @cargos_count)    
  BEGIN --1    
   --datos del cargo actual    
   SELECT @id_cargo = cpn.id_cargo    
    ,@monto_calculado_cargo = cpn.monto_calculado    
   FROM @Cargos_Por_Transaccion cpn    
   WHERE cpn.id_cargo_trasaccion = @i    
    
   SET @j = 1;    
    
   --Iterar cada impuesto    
   WHILE (@j <= @impuestos_count)    
   BEGIN --2    
    SELECT @id_impuesto = ipa.id_impuesto    
     ,@tipo_impuesto = ipa.tipo_impuesto    
     ,@id_tipo_condicion_IVA = ipa.id_tipo_condicion_IVA    
    FROM @Impuestos_Por_Cta ipa    
    WHERE id_impuesto_por_cta = @j;    
    
    IF (@tipo_impuesto = 'IVA')    
     --SP RF8    
     EXEC @ret_code = Configurations.dbo.Batch_Liq_Calcular_Impuestos_IVA_Cargos @id_cargo    
      ,@CreateTimestamp    
   ,@id_tipo_condicion_IVA    
      ,@monto_calculado_cargo    
      ,@monto_calculado_impuesto OUTPUT    
      ,@alicuota OUTPUT;    
    
    IF (@ret_code = 0) THROW 51000    
     ,'Error en SP - Batch_Liq_Calcular_Impuestos_IVA_Cargos'    
     ,1;    
     /*    
   ELSE IF(@tipo_impuesto = 'AGIP')    
   --SP RF9    
   ELSE IF(@tipo_impuesto = 'ARBA')    
   --SP RF10    
   ELSE IF(@tipo_impuesto = 'IVA_RG_2126')    
   --SP RF11    
   ELSE IF(@tipo_impuesto = 'IVA_RG_2408')    
   --SP RF12    
   */    
     --Insertar en tabla temp. @Impuestos_Por_TX    
     INSERT INTO @Impuestos_Por_TX (    
      id_cargo    
      ,id_impuesto    
      ,monto_calculado    
      ,alicuota    
      )    
     VALUES (    
      @id_cargo    
      ,@id_impuesto    
      ,@monto_calculado_impuesto    
      ,@alicuota    
      )    
    
    SET @j += 1;    
   END;--2    
    
   SET @i += 1;    
  END;--1    
    
  --Insertar en tabla Impuesto_Por_Transaccion    
  INSERT INTO Configurations.dbo.Impuesto_Por_Transaccion (    
   id_transaccion    
   ,id_cargo    
   ,id_impuesto    
   ,monto_calculado    
   ,alicuota    
   ,fecha_alta    
   ,usuario_alta    
   ,version    
   )    
  SELECT @Id    
   ,ipx.id_cargo    
   ,ipx.id_impuesto    
   ,ipx.monto_calculado    
   ,ipx.alicuota    
   ,GETDATE()    
   ,@Usuario    
   ,0    
  FROM @Impuestos_Por_TX ipx;    
    
  SELECT @TaxAmount = ISNULL(SUM(monto_calculado), 0)    
  FROM @Impuestos_Por_TX;    
    
  SET @ret_code = 1;    
 END TRY    
    
 BEGIN CATCH    
    
  SET @ret_code = 0;--en caso de excepcion fuera del THROW    
  SET @TaxAmount = 0;    
    
  PRINT ERROR_MESSAGE();  
    
 END CATCH    
    
 RETURN @ret_code;    
END
GO
/****** Object:  StoredProcedure [dbo].[Batch_Liq_Calcular_Impuestos_IVA_Cargos]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Liq_Calcular_Impuestos_IVA_Cargos] (
 @IdCargo INT
 ,@CreateTimestamp DATETIME
 ,@idTipoCondicionIVA INT
 ,@MontoCalculadoCargo DECIMAL(12, 2)
 ,@MontoCalculadoImpuesto DECIMAL(12, 2) OUTPUT
 ,@Alicuota DECIMAL(12, 2) OUTPUT
 )
AS
DECLARE @alicuota_tmp DECIMAL(12, 2) = 0;
DECLARE @msg VARCHAR(255) = NULL;
DECLARE @ret_code INT = 1;--sin errores

SET NOCOUNT ON;

BEGIN TRY
 --Obtener datos para el calculo
 SELECT @alicuota_tmp = ipt.alicuota
 FROM Configurations.dbo.Impuesto AS ipo
  ,Configurations.dbo.Impuesto_Por_Tipo AS ipt
  ,Configurations.dbo.Cargo AS cgo
  ,Configurations.dbo.Tipo_Cargo AS tgo
 WHERE cgo.id_cargo = @IdCargo
  AND cgo.id_tipo_cargo = tgo.id_tipo_cargo
  AND tgo.flag_aplica_iva = 1
  AND ipo.codigo = 'IVA'
  AND ipo.id_impuesto = ipt.id_impuesto
  AND ipt.id_tipo = @idTipoCondicionIVA
  AND CAST(ipt.fecha_vigencia_inicio AS DATE) <= CAST(@CreateTimestamp AS DATE)
  AND (
	  ipt.fecha_vigencia_fin IS NULL
	  OR CAST(ipt.fecha_vigencia_fin AS DATE) >= CAST(@CreateTimestamp AS DATE)
	  );

 IF (@alicuota_tmp IS NULL) THROW 51000
  ,'El valor de alícuota es Nulo'
  ,1;
  SET @MontoCalculadoImpuesto = (@alicuota_tmp / 100) * @MontoCalculadoCargo;
 SET @Alicuota = @alicuota_tmp;
END TRY

BEGIN CATCH
 SET @ret_code = 0;
END CATCH;

RETURN @ret_code;
GO
/****** Object:  StoredProcedure [dbo].[Batch_Liq_Detallar_Cargos_Devolucion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
    
create PROCEDURE [dbo].[Batch_Liq_Detallar_Cargos_Devolucion] (    
 @Id CHAR(36),    
 @FeeAmount DECIMAL(12, 2),    
 @Usuario VARCHAR(20)    
 )    
AS    
DECLARE @tx_Id CHAR(36);    
DECLARE @tx_FeeAmount DECIMAL(12, 2);    
DECLARE @ret_code INT;    
    
BEGIN    
 SET NOCOUNT ON;    
    
 BEGIN TRY    
  -- Obtener ID y Cargo de la Transacción sobre la que se realiza la Devolución    
  SELECT @tx_Id = Id,    
   @tx_FeeAmount = FeeAmount    
  FROM Transactions.dbo.transactions    
  WHERE Id = (    
    SELECT OriginalOperationId    
    FROM Transactions.dbo.transactions    
    WHERE Id = @Id    
    );    
    
  -- Insertar el detalle de Cargos de la Devolución basado en los Cargos de la Transacción    
  INSERT INTO Configurations.dbo.Cargos_Por_Transaccion (    
   id_cargo,    
   id_transaccion,    
   monto_calculado,    
   valor_aplicado,    
   id_tipo_aplicacion,    
   fecha_alta,    
   usuario_alta,    
   version    
   )    
  SELECT id_cargo,    
   @Id,    
   monto_calculado * IIF(@tx_FeeAmount = 0,0,(@FeeAmount * 100 / @tx_FeeAmount)) / 100,    
   valor_aplicado,    
   id_tipo_aplicacion,    
   GETDATE(),    
   @Usuario,    
   0    
  FROM Configurations.dbo.Cargos_Por_Transaccion    
  WHERE id_transaccion = @tx_Id;    
    
  SET @ret_code = 1;    
 END TRY    
    
 BEGIN CATCH    
  SET @ret_code = 0;    
  PRINT ERROR_MESSAGE();  
 END CATCH    
    
 RETURN @ret_code;    
END 
GO
/****** Object:  StoredProcedure [dbo].[Batch_Liq_Detallar_Impuestos_Devolucion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Liq_Detallar_Impuestos_Devolucion] (
 @Id CHAR(36)
 ,@TaxAmount DECIMAL(12, 2)
 ,@Usuario VARCHAR(20)
 )
AS
DECLARE @tx_Id CHAR(36);
DECLARE @tx_TaxAmount DECIMAL(12, 2);
DECLARE @ret_code INT;

BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  -- Obtener ID y Cargo de la Transacción sobre la que se realiza la Devolución      
  SELECT @tx_Id = Id
   ,@tx_TaxAmount = TaxAmount
  FROM Transactions.dbo.transactions
  WHERE Id = (
    SELECT OriginalOperationId
    FROM Transactions.dbo.transactions
    WHERE Id = @Id
    );

  -- Insertar el detalle de Cargos de la Devolución basado en los Cargos de la Transacción      
  INSERT INTO Configurations.dbo.Impuesto_Por_Transaccion (
   id_impuesto
   ,id_cargo
   ,id_transaccion
   ,monto_calculado
   ,alicuota
   ,fecha_alta
   ,usuario_alta
   ,version
   )
  SELECT id_impuesto
   ,id_cargo
   ,@Id
   ,monto_calculado * IIF(@tx_TaxAmount = 0, 0, (@TaxAmount * 100 / @tx_TaxAmount)) / 100
   ,alicuota * IIF(@tx_TaxAmount = 0, 0, (@TaxAmount / @tx_TaxAmount * 100)) / 100
   ,GETDATE()
   ,@Usuario
   ,0
  FROM Configurations.dbo.Impuesto_Por_Transaccion
  WHERE id_transaccion = @tx_Id;

  SET @ret_code = 1;
 END TRY

 BEGIN CATCH
  SET @ret_code = 0;

  PRINT ERROR_MESSAGE();
 END CATCH

 RETURN @ret_code;
END
GO
/****** Object:  StoredProcedure [dbo].[Batch_Liq_Main]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Liq_Main] (@Usuario VARCHAR(20))
AS
DECLARE @id_log_proceso INT;
DECLARE @id_tipo_movimiento INT;
DECLARE @id_tipo_origen_movimiento INT;
DECLARE @tx_count INT;
DECLARE @tx_i INT = 1;
DECLARE @Id CHAR(36);
DECLARE @CreateTimestamp DATETIME;
DECLARE @LocationIdentification INT;
DECLARE @ProductIdentification INT;
DECLARE @OperationName VARCHAR(128);
DECLARE @Amount DECIMAL(12, 2);
DECLARE @FeeAmount DECIMAL(12, 2);
DECLARE @TaxAmount DECIMAL(12, 2);
DECLARE @CashoutTimestamp DATETIME;
DECLARE @FilingDeadline DATETIME;
DECLARE @PaymentTimestamp DATETIME;
DECLARE @FacilitiesPayments INT;
DECLARE @LiquidationStatus INT;
DECLARE @LiquidationTimestamp DATETIME;
DECLARE @PromotionIdentification INT;
DECLARE @ButtonCode VARCHAR(20);
DECLARE @flag_ok INT;
DECLARE @flag_dev INT;
DECLARE @saldo DECIMAL(12, 2);
DECLARE @fecha_base_de_cashout DATE;
DECLARE @fecha_de_cashout DATE;
DECLARE @id_codigo_operacion INT;
DECLARE @registros_afectados INT;
DECLARE @TransactionStatus VARCHAR(20);

BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  -- Iniciar Log        
  EXEC @id_log_proceso = Configurations.dbo.Iniciar_Log_Proceso 1
   ,NULL
   ,NULL
   ,@Usuario;

  -- Obtener ID de tipo de movimiento      
  SELECT @id_tipo_movimiento = tpo.id_tipo
  FROM dbo.Tipo tpo
  WHERE tpo.codigo = 'MOV_CRED'
   AND tpo.id_grupo_tipo = 16;

  -- Obtener ID de origen de movimiento      
  SELECT @id_tipo_origen_movimiento = tpo.id_tipo
  FROM dbo.Tipo tpo
  WHERE tpo.codigo = 'ORIG_PROCESO'
   AND tpo.id_grupo_tipo = 17;

  -- Obtener Transacciones a Liquidar        
  EXEC @tx_count = Configurations.dbo.Batch_Liq_Obtener_Transacciones;

  -- Para cada transacción      
  WHILE (@tx_i <= @tx_count)
  BEGIN
   BEGIN TRY
    -- Leer Transacción      
    SELECT @Id = tmp.Id
     ,@CreateTimestamp = tmp.CreateTimestamp
     ,@LocationIdentification = tmp.LocationIdentification
     ,@ProductIdentification = tmp.ProductIdentification
     ,@OperationName = tmp.OperationName
     ,@Amount = tmp.Amount
     ,@FeeAmount = tmp.FeeAmount
     ,@TaxAmount = tmp.TaxAmount
     ,@CashoutTimestamp = tmp.CashoutTimestamp
     ,@FilingDeadline = tmp.FilingDeadline
     ,@PaymentTimestamp = tmp.PaymentTimestamp
     ,@FacilitiesPayments = tmp.FacilitiesPayments
     ,@LiquidationStatus = tmp.LiquidationStatus
     ,@LiquidationTimestamp = tmp.LiquidationTimestamp
     ,@PromotionIdentification = tmp.PromotionIdentification
     ,@ButtonCode = tmp.ButtonCode
     ,@TransactionStatus = tmp.TransactionStatus
    FROM Configurations.dbo.Liquidacion_Tmp tmp
    WHERE tmp.i = @tx_i;

    IF (@Id IS NOT NULL)
    BEGIN
     BEGIN TRANSACTION;

     SET @flag_ok = 1;
    END
    ELSE
     SET @flag_ok = 0;

    -- Si no hay error y es una Compra, calcular Cargos      
    IF (
      @flag_ok = 1
      AND UPPER(@OperationName) IN (
       'COMPRA_OFFLINE'
       ,'COMPRA_ONLINE'
       )
      )
    BEGIN
     EXEC @flag_ok = Configurations.dbo.Batch_Liq_Calcular_Cargos @Id
      ,@CreateTimestamp
      ,@LocationIdentification
      ,@ProductIdentification
      ,@Amount
      ,@PromotionIdentification
      ,@FacilitiesPayments
      ,@ButtonCode
      ,@Usuario
      ,@FeeAmount OUTPUT;

     IF (@flag_ok = 0)
     BEGIN
      PRINT 'id= ' + @Id;
      PRINT 'Batch_Liq_Calcular_Cargos - @flag_ok: ' + cast(@flag_ok AS CHAR(1));
     END;
    END;

    -- Si es una Devolución detallar los Cargos calculados      
    IF (
      @flag_ok = 1
      AND (
       UPPER(@OperationName) = 'DEVOLUCION'
       AND @FeeAmount IS NOT NULL
       )
      )
    BEGIN
     EXEC @flag_ok = Configurations.dbo.Batch_Liq_Detallar_Cargos_Devolucion @Id
      ,@FeeAmount
      ,@Usuario;

     IF (@flag_ok = 0)
     BEGIN
      PRINT 'id= ' + @Id;
      PRINT 'Batch_Liq_Detallar_Cargos_Devolucion - @flag_ok: ' + cast(@flag_ok AS CHAR(1));
     END;
    END;

    --flag_dev = 1 (devolucion) - 0 (compra)    
    SET @flag_dev = IIF(UPPER(@OperationName) IN (
       'COMPRA_OFFLINE'
       ,'COMPRA_ONLINE'
       ), 0, 1);

    -- Si es devolucion, obtener @PromotionIdentification de la tx original    
    IF (@flag_dev = 1)
    BEGIN
     SELECT @PromotionIdentification = PromotionIdentification
     FROM Transactions.dbo.transactions
     WHERE Id = (
       SELECT OriginalOperationId
       FROM Transactions.dbo.transactions
       WHERE Id = @Id
       );
    END;

    -- Validar si no hay error/si esta asociado a una promocion vigente    
    IF (
      @flag_ok = 1
      AND @PromotionIdentification IS NOT NULL --Asociado a una promocion    
      AND
      --Si es promocion vigente    
      EXISTS (
       SELECT 1
       FROM Configurations.dbo.Regla_Bonificacion rb
       WHERE rb.id_regla_bonificacion = @PromotionIdentification
        AND (
         rb.fecha_baja IS NULL
         OR CAST(rb.fecha_baja AS DATE) > CAST(@CreateTimestamp AS DATE)
         )
        AND CAST(rb.fecha_desde AS DATE) <= CAST(@CreateTimestamp AS DATE)
        AND (
         rb.fecha_hasta IS NULL
         OR CAST(rb.fecha_hasta AS DATE) >= CAST(@CreateTimestamp AS DATE)
         )
       )
      )
    BEGIN
     EXEC @flag_ok = Configurations.dbo.Batch_Liq_Actualizar_Acumulador_Promociones @CreateTimestamp
      ,@LocationIdentification
      ,@Amount
      ,@PromotionIdentification
      ,@flag_dev;

     IF (@flag_ok = 0)
     BEGIN
      PRINT 'id= ' + @Id;
      PRINT 'Batch_Liq_Actualizar_Acumulador_Promociones - @flag_ok: ' + cast(@flag_ok AS CHAR(1));
     END;
    END;

    -- Si no hay error calcular Impuestos                          
    IF (
      @flag_ok = 1
      AND
      -- Si es una Compra                 
      UPPER(@OperationName) IN (
       'COMPRA_OFFLINE'
       ,'COMPRA_ONLINE'
       )
      )
    BEGIN
     EXEC @flag_ok = Configurations.dbo.Batch_Liq_Calcular_Impuestos @Id
      ,@CreateTimestamp
      ,@LocationIdentification
      ,@Usuario
      ,@TaxAmount OUTPUT;

     IF (@flag_ok = 0)
     BEGIN
      PRINT 'id= ' + @Id;
      PRINT 'Batch_Liq_Calcular_Impuestos - @flag_ok: ' + cast(@flag_ok AS CHAR(1));
     END;
    END;

    -- Si es una Devolución                          
    IF (
      @flag_ok = 1
      AND UPPER(@OperationName) = 'DEVOLUCION'
      AND @TaxAmount IS NOT NULL
      )
    BEGIN
     EXEC @flag_ok = Configurations.dbo.Batch_Liq_Detallar_Impuestos_Devolucion @Id
      ,@TaxAmount
      ,@Usuario;

     IF (@flag_ok = 0)
     BEGIN
      PRINT 'id= ' + @Id;
      PRINT 'Batch_Liq_Detallar_Impuestos_Devolucion - @flag_ok: ' + cast(@flag_ok AS CHAR(1));
     END;
    END;

    -- Si no hay error y es Compra, calcular Fecha de Cashout                          
    IF (
      @flag_ok = 1
      AND UPPER(@OperationName) IN (
       'COMPRA_OFFLINE'
       ,'COMPRA_ONLINE'
       )
      )
    BEGIN
     EXEC @flag_ok = Configurations.dbo.Batch_Liq_Calcular_Fecha_Cashout @CreateTimestamp
      ,@LocationIdentification
      ,@ProductIdentification
      ,@FacilitiesPayments
      ,@PaymentTimestamp
      ,@CashoutTimestamp OUTPUT;

     IF (@flag_ok = 0)
     BEGIN
      PRINT 'id= ' + @Id;
      PRINT 'Batch_Liq_Calcular_Fecha_Cashout - @flag_ok: ' + cast(@flag_ok AS CHAR(1));
     END;
    END;

    -- Si no hay error calcular Fecha Tope de Presentación                          
    IF (@flag_ok = 1)
    BEGIN
     EXEC @flag_ok = Configurations.dbo.Batch_Liq_Calcular_Fecha_Tope_Presentacion @ProductIdentification
      ,@CreateTimestamp
      ,@FilingDeadline OUTPUT;

     IF (@flag_ok = 0)
     BEGIN
      PRINT 'id= ' + @Id;
      PRINT 'Batch_Liq_Calcular_Fecha_Tope_Presentacion - @flag_ok: ' + cast(@flag_ok AS CHAR(1));
     END;
    END;

    -- Si no hay error actualizar la Transaccion en la tabla temporal                          
    IF (@flag_ok = 1)
    BEGIN
     -- Si es una Compra                          
     IF (
       UPPER(@OperationName) IN (
        'COMPRA_OFFLINE'
        ,'COMPRA_ONLINE'
        )
       )
     BEGIN
      UPDATE Configurations.dbo.Liquidacion_Tmp
      SET FeeAmount = @FeeAmount
       ,TaxAmount = @TaxAmount
       ,CashoutTimestamp = @CashoutTimestamp
       ,FilingDeadline = @FilingDeadline
       ,Flag_Ok = 1
      WHERE i = @tx_i;
     END;

     -- Si es una Devolución                          
     IF (UPPER(@OperationName) = 'DEVOLUCION')
     BEGIN
      UPDATE Configurations.dbo.Liquidacion_Tmp
      SET FilingDeadline = @FilingDeadline
       ,Flag_Ok = 1
      WHERE i = @tx_i;
     END;
    END
    ELSE IF (@flag_ok = 0)
    BEGIN
     -- Si hay error, marcar la Transaccion en la tabla temporal                          
     UPDATE Configurations.dbo.Liquidacion_Tmp
     SET Flag_Ok = 0
     WHERE i = @tx_i;
    END;

    SET @saldo = @Amount - @FeeAmount - @TaxAmount;

    -- Si no hay error Actualizar Cuenta Virtual      
    IF (
      @flag_ok = 1
      AND UPPER(@OperationName) IN (
       'COMPRA_OFFLINE'
       ,'COMPRA_ONLINE'
       )
      )
    BEGIN
     EXEC @flag_ok = Configurations.dbo.Actualizar_Cuenta_Virtual NULL
      ,NULL
      ,@saldo
      ,NULL
      ,NULL
      ,NULL
      ,@LocationIdentification
      ,@Usuario
      ,@id_tipo_movimiento
      ,@id_tipo_origen_movimiento
      ,@id_log_proceso;

     IF (@flag_ok = 0)
     BEGIN
      PRINT 'id= ' + @Id;
      PRINT 'Actualizar_Cuenta_Virtual - @flag_ok: ' + cast(@flag_ok AS CHAR(1));
     END;
    END;

    -- Si no hay error Actualizar el Control de Disponible      
    IF (@flag_ok = 1)
    BEGIN
     -- Obtener fechas y codigo de operación      
     SELECT @fecha_base_de_cashout = CAST((
        CASE 
         WHEN tmp.codigo = 'EFECTIVO'
          THEN ltp.PaymentTimestamp
         ELSE ltp.CreateTimestamp
         END
        ) AS DATE)
      ,@fecha_de_cashout = CAST(ltp.CashoutTimestamp AS DATE)
      ,@id_codigo_operacion = cop.id_codigo_operacion
     FROM Configurations.dbo.Liquidacion_Tmp ltp
     INNER JOIN Configurations.dbo.Medio_De_Pago mdp ON ltp.ProductIdentification = mdp.id_medio_pago
     INNER JOIN Configurations.dbo.Tipo_Medio_Pago tmp ON mdp.id_tipo_medio_pago = tmp.id_tipo_medio_pago
     INNER JOIN Configurations.dbo.Codigo_Operacion cop ON cop.codigo_operacion = (
       CASE 
        WHEN ltp.OperationName = 'devolucion'
         THEN 'DEV'
        ELSE 'COM'
        END
       )
     WHERE ltp.i = @tx_i;

     -- Actualizar      
     EXEC @flag_ok = Configurations.dbo.Batch_Actualizar_Control_Liquidacion_Disponible @id_log_proceso
      ,@Id
      ,@fecha_base_de_cashout
      ,@fecha_de_cashout
      ,@LocationIdentification
      ,@id_codigo_operacion
      ,@saldo;

     IF (@flag_ok = 0)
     BEGIN
      PRINT 'id= ' + @Id;
      PRINT 'Batch_Actualizar_Control_Liquidacion_Disponible - @flag_ok: ' + cast(@flag_ok AS CHAR(1));
     END;
    END;

    -- Si no hay error Actualizar transaccion      
    IF (@flag_ok = 1)
    BEGIN
     UPDATE Transactions.dbo.transactions
     SET Transactions.dbo.transactions.FeeAmount = @FeeAmount
      ,Transactions.dbo.transactions.TaxAmount = @TaxAmount
      ,Transactions.dbo.transactions.CashoutTimestamp = @CashoutTimestamp
      ,Transactions.dbo.transactions.FilingDeadline = @FilingDeadline
      ,Transactions.dbo.transactions.LiquidationStatus = - 1
      ,Transactions.dbo.transactions.LiquidationTimestamp = GETDATE()
      ,Transactions.dbo.transactions.TransactionStatus = (
       CASE 
        WHEN UPPER(@OperationName) IN (
          'COMPRA_OFFLINE'
          ,'COMPRA_ONLINE'
          )
         THEN 'TX_APROBADA'
        WHEN UPPER(@OperationName) = 'DEVOLUCION'
         THEN @TransactionStatus
        END
       )
      ,Transactions.dbo.transactions.SyncStatus = 0
     WHERE Id = @Id;
    END;

    -- SI HAY ERROR, lanzar excepción para deshacer las modificaciones      
    IF (@flag_ok = 0)
    BEGIN
     THROW 51000
      ,'Error procesando la Transacción'
      ,1;
    END;

    COMMIT TRANSACTION;
   END TRY

   BEGIN CATCH
    PRINT ERROR_MESSAGE();

    -- Deshacer las modificaciones      
    ROLLBACK TRANSACTION;

    BEGIN TRANSACTION;

    -- Marcar la Transacción como procesada con error.      
    UPDATE Transactions.dbo.transactions
    SET Transactions.dbo.transactions.LiquidationStatus = Transactions.dbo.transactions.LiquidationStatus + 1
     ,Transactions.dbo.transactions.SyncStatus = 0
    WHERE Id = @Id;

    COMMIT TRANSACTION;
   END CATCH;

   -- Siguiente Transacción      
   SET @tx_i += 1;
  END;

  -- Contar registros afectados      
  SELECT @registros_afectados = COUNT(1)
  FROM Configurations.dbo.Liquidacion_Tmp
  WHERE Flag_Ok = 1;

  -- Completar Log de Proceso      
  EXEC @flag_ok = Configurations.dbo.Finalizar_Log_Proceso @id_log_proceso
   ,@registros_afectados
   ,@Usuario;

  RETURN 1;
 END TRY

 BEGIN CATCH
  PRINT ERROR_MESSAGE();

  IF (@@TRANCOUNT > 0)
   ROLLBACK TRANSACTION;

  RETURN 0;
 END CATCH
END

GO
/****** Object:  StoredProcedure [dbo].[Batch_Liq_Obtener_Cargos_Por_Devolucion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Liq_Obtener_Cargos_Por_Devolucion] (
 @p_Id CHAR(36)
 ,@p_Amount DECIMAL(12, 2)
 ,@p_ret_code INT OUTPUT
 ,@p_FeeAmount DECIMAL(12, 2) OUTPUT
 ,@p_TaxAmount DECIMAL(12, 2) OUTPUT
 )
AS
DECLARE @Amount DECIMAL(12, 2);
DECLARE @FeeAmount DECIMAL(12, 2);
DECLARE @TaxAmount DECIMAL(12, 2);
DECLARE @RefundAmount DECIMAL(12, 2);
DECLARE @FeeDisponible DECIMAL(12, 2);
DECLARE @TaxDisponible DECIMAL(12, 2);

BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  -- Buscar la Transacción sobre la que se efectúa la Devolución      
  SELECT @Amount = Amount
   ,@FeeAmount = FeeAmount
   ,@TaxAmount = TaxAmount
   ,@RefundAmount = ISNULL(RefundAmount, 0)
  FROM Transactions.dbo.transactions
  WHERE Id = @p_Id;

  -- Si no se encuentra la Transacción o está incompleta      
  IF (
    @Amount IS NULL
    OR @FeeAmount IS NULL
    OR @TaxAmount IS NULL
    )
  BEGIN
   throw 51000
    ,'No existe la Transacción o está incompleta.'
    ,1;
  END;

  -- Si la Devolución supera el monto disponible para devolver      
  IF (@Amount - @RefundAmount < @p_Amount)
  BEGIN
   throw 51000
    ,'El monto de la Devolución es mayor al permitido para la Transacción.'
    ,1;
  END;

  -- Calcular el porcentaje de Cargos e Impuestos correspondiente a la Devolución      
  SET @p_FeeAmount = @FeeAmount * (@p_Amount * 100 / @Amount) / 100;
  SET @p_TaxAmount = @TaxAmount * (@p_Amount * 100 / @Amount) / 100;

  -- Si hubo devoluciones parciales, verificar diferencias por redondeo en Cargos e Impuestos      
  SELECT @FeeDisponible = @FeeAmount - sum(FeeAmount)
   ,@TaxDisponible = @TaxAmount - sum(TaxAmount)
  FROM Transactions.dbo.transactions
  WHERE OriginalOperationId = @p_Id
   AND ResultCode = - 1;

  -- Si el Fee calculado supera al disponible      
  IF (@p_FeeAmount > @FeeDisponible)
   SET @p_FeeAmount = @FeeDisponible;

  -- Si el Tax calculado supera al disponible      
  IF (@p_TaxAmount > @TaxDisponible)
   SET @p_TaxAmount = @TaxDisponible;
  -- Proceso OK      
  SET @p_ret_code = 1;
 END TRY

 BEGIN CATCH
  SET @p_FeeAmount = NULL;
  SET @p_TaxAmount = NULL;
  SET @p_ret_code = 2013;
 END CATCH;

 RETURN @p_ret_code;
END
GO
/****** Object:  StoredProcedure [dbo].[Batch_Liq_Obtener_Transacciones]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Liq_Obtener_Transacciones]
AS
DECLARE @rows INT = 0;

BEGIN
 SET NOCOUNT ON;

 BEGIN TRY
  TRUNCATE TABLE Configurations.dbo.Liquidacion_Tmp;

  BEGIN TRANSACTION;

  INSERT INTO Configurations.dbo.Liquidacion_Tmp
  SELECT ROW_NUMBER() OVER (
    ORDER BY CreateTimestamp
    ) AS I
   ,mov.*
  FROM (
   -- Transacciones            
   SELECT trn.Id
    ,trn.CreateTimestamp
    ,trn.LocationIdentification
    ,trn.ProductIdentification
    ,trn.OperationName
    ,trn.Amount
    ,trn.FeeAmount
    ,trn.TaxAmount
    ,trn.CashoutTimestamp
    ,trn.FilingDeadline
    ,trn.PaymentTimestamp
    ,trn.FacilitiesPayments
    ,trn.LiquidationStatus
    ,trn.LiquidationTimestamp
    ,trn.PromotionIdentification
    ,(
     SELECT LTRIM(RTRIM(tpo.codigo))
     FROM Configurations.dbo.Boton btn
     INNER JOIN Configurations.dbo.Tipo tpo ON btn.id_tipo_concepto_boton = tpo.id_tipo
     WHERE trn.ButtonId = btn.id_boton
      AND tpo.id_grupo_tipo = 12
      AND LTRIM(RTRIM(tpo.codigo)) IN (
       'CPTO_BTN_VTA'
       ,'CPTO_BTN_AJ_CTGO'
       ,'CPTO_BTN_VAL_MP'
       )
     ) AS ButtonCode
    ,0 AS Flag_Ok
    ,trn.TransactionStatus
   FROM Transactions.dbo.Transactions trn
   INNER JOIN Configurations.dbo.Medio_De_Pago mdp ON trn.ProductIdentification = mdp.id_medio_pago
   INNER JOIN Configurations.dbo.Tipo_Medio_Pago tmp ON mdp.id_tipo_medio_pago = tmp.id_tipo_medio_pago
   WHERE LTRIM(RTRIM(UPPER(trn.OperationName))) IN (
     'COMPRA_OFFLINE'
     ,'COMPRA_ONLINE'
     )
    AND trn.ResultCode = - 1
    AND trn.LiquidationTimestamp IS NULL
    AND (
     trn.LiquidationStatus IS NULL
     OR trn.LiquidationStatus BETWEEN 0
      AND 50
     )
    AND trn.TransactionStatus = 'TX_PROCESADA'
    AND mdp.flag_habilitado > 0
    AND (
     (
      LTRIM(RTRIM(tmp.codigo)) IN (
       'CREDITO'
       ,'DEBITO'
       )
      )
     OR (
      LTRIM(RTRIM(tmp.codigo)) = 'EFECTIVO'
      AND trn.PaymentTimestamp IS NOT NULL
      )
     )
   
   UNION ALL
   
   -- Devoluciones            
   SELECT trn.Id
    ,trn.CreateTimestamp
    ,trn.LocationIdentification
    ,trn.ProductIdentification
    ,trn.OperationName
    ,trn.Amount
    ,trn.FeeAmount
    ,trn.TaxAmount
    ,trn.CashoutTimestamp
    ,trn.FilingDeadline
    ,trn.PaymentTimestamp
    ,trn.FacilitiesPayments
    ,trn.LiquidationStatus
    ,trn.LiquidationTimestamp
    ,trn.PromotionIdentification
    ,NULL AS ButtonCode
    ,0 AS Flag_Ok
    ,trn.TransactionStatus
   FROM Transactions.dbo.Transactions trn
   WHERE LTRIM(RTRIM(UPPER(trn.OperationName))) = 'DEVOLUCION'
    AND trn.ResultCode = - 1
    AND trn.LiquidationTimestamp IS NULL
    AND (
     trn.LiquidationStatus IS NULL
     OR trn.LiquidationStatus BETWEEN 0
      AND 50
     )
    AND trn.TransactionStatus IN (
     'TX_APROBADA'
     ,'TX_DISPONIBLE'
     )
    AND trn.FeeAmount IS NOT NULL
    AND trn.TaxAmount IS NOT NULL
   ) mov
  WHERE (
    mov.ButtonCode IS NULL
    OR mov.ButtonCode <> 'CPTO_BTN_VAL_MP'
    );

  SET @rows = @@ROWCOUNT;

  COMMIT TRANSACTION;
 END TRY

 BEGIN CATCH
  ROLLBACK TRANSACTION;
 END CATCH

 RETURN @rows;
END
GO
/****** Object:  StoredProcedure [dbo].[Batch_VencMediosDePago_Actualizar_notificados]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Batch_VencMediosDePago_Actualizar_notificados] (                  
 @v_id_medio_pago_cuenta INT,      
 @usuario VARCHAR(20)             
                  
)                              
AS                   
    
DECLARE @CodRet INT    
                  
SET NOCOUNT ON;      
    
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;                  
                
BEGIN TRANSACTION                  
                  
BEGIN TRY                  
       
BEGIN    
  UPDATE Configurations.dbo.medio_pago_cuenta     
  SET     
  medio_notificado=1,    
  fecha_modificacion=getdate(),    
  usuario_modificacion=@usuario    
  WHERE id_medio_pago_cuenta=@v_id_medio_pago_cuenta;    
           
END                  
          
                  
COMMIT TRANSACTION;      
    
SET @CodRet=1;    
             
END TRY                  
    
BEGIN CATCH                  
     
 IF (@@TRANCOUNT > 0)    
                   
  ROLLBACK TRANSACTION;                   
  SET @CodRet=0;    
  RETURN @CodRet;         
    
END CATCH                  
                  
          
                  
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;                  
                  
RETURN @CodRet; 
GO
/****** Object:  StoredProcedure [dbo].[Batch_VencMediosDePago_Main]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Batch_VencMediosDePago_Main]             
(            
 @id_log_proceso INT = NULL,            
 @usuario VARCHAR(20) = NULL            
             
)                    
                
AS            
            
--Variables nuevas            
DECLARE @v_tarjetas_count INT;            
DECLARE @v_tarjetas_i INT;            
declare @v_id_estado_vencido INT;          
declare @Total_ConErrores INT;            
declare @Total_Procesados INT;              
            
--Variables flags            
DECLARE @Flag_OK_While INT;            
DECLARE @Flag_rangoBin_count INT;            
DECLARE @Flag_OK_LogPaso INT;             
            
--Variables de uso temporal            
DECLARE @v_id_medio_pago_cuenta INT;            
DECLARE @v_Cuenta INT;            
DECLARE @v_mascara_numero_tarjeta VARCHAR(20);            
DECLARE @v_fecha_vencimiento VARCHAR(6);            
DECLARE @v_id_medio_pago INT;            
DECLARE @v_id_tipo_medio_pago INT;            
DECLARE @v_codigo VARCHAR(20);            
DECLARE @v_flag_tipo_de_medio VARCHAR(20);            
            
DECLARE @id_paso_proceso INT = NULL;            
DECLARE @msg VARCHAR(255) = NULL;            
DECLARE @id_log_paso INT = NULL            
            
            
            
SET NOCOUNT ON;            
            
BEGIN TRANSACTION;            
            
BEGIN TRY            
            
  SET @id_paso_proceso = 1;            
            
  BEGIN            
  -- Inicio Log paso proceso             
            
  EXEC  @id_log_paso = Configurations.dbo.Iniciar_Log_Paso_Proceso             
        @id_log_proceso,            
        @id_paso_proceso,            
        'MP-ProcesarVencimientos',            
        NULL,            
        @usuario;            
  END            
            
  BEGIN            
                 
   --Inicio de carga de datos            
  EXEC  @v_tarjetas_count=Configurations.dbo.Batch_VencMediosDePago_ObtenerRegistros            
        @Usuario;            
  END         
        
COMMIT TRANSACTION        
            
END TRY                    
              
BEGIN CATCH              
              
  IF (@@TRANCOUNT > 0)              
  ROLLBACK TRANSACTION;              
  RETURN 0;            
                   
END CATCH            
                
            
IF (@v_tarjetas_count<>0)            
                          
                           
                             
 SET @v_tarjetas_i = 1;             
            
 SELECT @v_id_estado_vencido=id_estado             
 FROM Configurations.dbo.Estado where Codigo='MP_VENCIDO'            
                    
 WHILE (@v_tarjetas_i <= @v_tarjetas_count)              
                       
 BEGIN            
                       
  BEGIN TRY            
            
  BEGIN TRANSACTION            
            
  -- Asumir error            
  SET @Flag_OK_While = 0;            
            
  SELECT            
   @v_id_medio_pago_cuenta=tmp.id_medio_pago_cuenta,            
   @v_Cuenta = tmp.id_cuenta,              
   @v_mascara_numero_tarjeta = tmp.mascara_numero_tarjeta,              
   @v_fecha_vencimiento = tmp.fecha_vencimiento,            
   @v_codigo=tmp.codigo,            
   @v_flag_tipo_de_medio=tmp.flag_tipo_de_medio            
   FROM Configurations.dbo.VencMediosDePago_tmp tmp             
   WHERE tmp.i = @v_tarjetas_i;            
               
   BEGIN            
              
    --Obtener el rango BIN            
   EXEC  @Flag_rangoBin_count=Configurations.dbo.Batch_VencMediosDePago_ObtenerRangoBin            
      @v_id_medio_pago_cuenta,            
      @v_mascara_numero_tarjeta,            
      @usuario,            
      @v_id_estado_vencido,            
      @v_flag_tipo_de_medio;            
   END              
            
   COMMIT TRANSACTION;            
            
   END TRY            
            
   BEGIN CATCH            
                                     
     IF (@@TRANCOUNT > 0)              
     ROLLBACK TRANSACTION;              
     RETURN 0;            
                       
   END CATCH            
                       
   -- Incrementar contador            
   SET @v_tarjetas_i += 1;             
                       
 END       
            
            
            
BEGIN            
                       
  BEGIN TRY            
            
  BEGIN TRANSACTION           
            
  SELECT @Total_ConErrores=ROUND(SUM(trn.RegistrosConError),2),@Total_Procesados=ROUND(SUM(trn.RegistrosProcesados),2)          
  FROM(          
  SELECT count(tmp.id_cuenta) as RegistrosConError,          
  0 as RegistrosProcesados          
  FROM Configurations.dbo.VencMediosDePago_tmp tmp          
  WHERE tmp.flag_error_informado=1          
  UNION          
  SELECT 0 as RegistrosConError,          
  count(tmp.id_cuenta) as RegistrosProcesados          
  FROM Configurations.dbo.VencMediosDePago_tmp tmp          
  WHERE tmp.flag_error_informado=0          
  )trn          
            
  EXEC @Flag_OK_LogPaso=Configurations.dbo.Finalizar_Log_Paso_Proceso            
    @id_log_paso,            
    null,            
    1,            
    null,            
    @v_tarjetas_count,            
    NULL,            
    @Total_Procesados,            
    NULL,            
    @Total_ConErrores,            
   NULL,            
    null,            
    null,            
    @Usuario;            
              
            
  COMMIT TRANSACTION;            
            
  RETURN 1;            
            
  END TRY            
            
  BEGIN CATCH            
            
    IF (@@TRANCOUNT > 0)              
    ROLLBACK TRANSACTION;              
    RETURN 0;            
              
  END CATCH            
END 
GO
/****** Object:  StoredProcedure [dbo].[Batch_VencMediosDePago_ObtenerRangoBin]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
                
CREATE PROCEDURE [dbo].[Batch_VencMediosDePago_ObtenerRangoBin] (                
 @v_id_medio_pago_cuenta INT,                
 @v_mascara_numero_tarjeta VARCHAR(20),                
 @usuario VARCHAR(20),                
 @v_id_estado_vencido INT,                
 @v_tipo_de_medio VARCHAR(20)                
                
)                            
AS                
                
DECLARE @v_valor_flag INT;                
DECLARE @id_rango_bin INT;                
DECLARE @rango BIGINT;                
DECLARE @flag_controla_vencimiento BIT;                
DECLARE @v_count_ids INT;                
DECLARE @AcumuladoIds VARCHAR(max)                
                
                
SET NOCOUNT ON;                
                
BEGIN TRANSACTION;                
                
BEGIN TRY                
                 
  BEGIN                
                 
  SELECT TOP 1 @id_rango_bin = rb.id_rango_bin,                
               @rango = CAST(rb.bin_hasta AS BIGINT) - cast(rb.bin_desde AS BIGINT),                
               @flag_controla_vencimiento = rb.flag_controla_vencimiento                
      FROM Configurations.dbo.Rango_BIN rb                
      WHERE @v_mascara_numero_tarjeta BETWEEN rb.bin_desde AND rb.bin_hasta                
   AND rb.flag_controla_vencimiento IS NOT NULL                
   ORDER BY CAST(rb.bin_hasta AS BIGINT) - cast(rb.bin_desde AS BIGINT) ASC                
                
  SELECT @v_count_ids=count(1)                
      FROM Configurations.dbo.Rango_BIN rb                
      WHERE @v_mascara_numero_tarjeta BETWEEN rb.bin_desde AND rb.bin_hasta                
     AND rb.id_rango_bin <> @id_rango_bin                
     AND (CAST(rb.bin_hasta AS BIGINT) - cast(rb.bin_desde AS BIGINT)) = @rango                
     AND (rb.flag_controla_vencimiento <> @flag_controla_vencimiento OR rb.flag_controla_vencimiento IS NULL)                
          
  END                
          
          
  IF (@v_count_ids<>0)                
          
                   
  BEGIN                
                   
    SELECT @AcumuladoIds = COALESCE(@AcumuladoIds + '; ' + cast(rb.id_rango_bin as varchar(20)), cast(rb.id_rango_bin as varchar(20)))                
     FROM Configurations.dbo.Rango_BIN rb                
     WHERE @v_mascara_numero_tarjeta BETWEEN rb.bin_desde AND rb.bin_hasta                
     ORDER BY CAST(rb.bin_hasta AS BIGINT) - cast(rb.bin_desde AS BIGINT) ASC                
                
    UPDATE Configurations.dbo.VencMediosDePago_tmp                 
     SET                 
     flag_error_informado=1,                
     id_error_BIN=@AcumuladoIds                
     WHERE id_medio_pago_cuenta=@v_id_medio_pago_cuenta;                
          
  END        
                      
  ELSE                
           
  BEGIN        
           
   IF (@flag_controla_vencimiento=1 and @v_tipo_de_medio='Vencidos')                
                    
    BEGIN                
                                 
     UPDATE Configurations.dbo.VencMediosDePago_tmp                 
     SET                 
     flag_error_informado=0                
     WHERE id_medio_pago_cuenta=@v_id_medio_pago_cuenta;                
                        
                          
     UPDATE Configurations.dbo.medio_pago_cuenta                 
     SET                 
     id_estado_medio_pago=@v_id_estado_vencido,                
     fecha_modificacion=getdate(),                
     usuario_modificacion=@usuario                
     WHERE id_medio_pago_cuenta=@v_id_medio_pago_cuenta;                
                             
    END                
            
    ELSE        
               
       IF (@flag_controla_vencimiento=1 and @v_tipo_de_medio='AVencer')               
               
   BEGIN        
            
      UPDATE Configurations.dbo.VencMediosDePago_tmp                 
      SET                 
      flag_error_informado=0                
      WHERE id_medio_pago_cuenta=@v_id_medio_pago_cuenta;         
              
   END        
                       
   END            
           
        
END TRY                
        
                
BEGIN CATCH                
                
IF (@@TRANCOUNT > 0)          
  ROLLBACK TRANSACTION;        
  RETURN 0;        
                   
                
END CATCH;                
        
COMMIT TRANSACTION;                
              
RETURN 1; 
GO
/****** Object:  StoredProcedure [dbo].[Batch_VencMediosDePago_ObtenerRegistros]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  StoredProcedure [dbo].[Batch_VueltaFacturacion_ObtenerRegistros]    Script Date: 31/07/2015 11:48:04 ******/        
        
CREATE PROCEDURE [dbo].[Batch_VencMediosDePago_ObtenerRegistros] (            
  @Usuario VARCHAR(20)        
        
)        
        
AS          
  DECLARE @rows INT;          
  DECLARE @I INT;                
          
        
BEGIN                    
 SET NOCOUNT ON;              
              
 BEGIN TRY              
          
  TRUNCATE TABLE Configurations.dbo.VencMediosDePago_tmp;              
                
  BEGIN TRANSACTION;              
               
  INSERT INTO [dbo].[VencMediosDePago_tmp] (        
   [I],        
   [id_medio_pago_cuenta],        
   [id_cuenta],        
   [codigo],        
   [denominacion1],        
   [denominacion2],        
   [mascara_numero_tarjeta],        
   [eMail],        
   [fecha_vencimiento],        
   [flag_tipo_de_medio]             
   )        
  SELECT ROW_NUMBER() OVER (        
    ORDER BY id_cuenta        
    ) AS I,        
   f.[id_medio_pago_cuenta],        
   f.[id_cuenta],        
   f.[codigo],        
   f.[denominacion1],        
   f.[denominacion2],        
   f.[mascara_numero_tarjeta],        
   f.[eMail],        
   f.[fecha_vencimiento],        
   f.[flag_tipo_de_medio]           
  FROM (        
   SELECT          
    mpc.id_medio_pago_cuenta,        
    mpc.id_cuenta,        
    mp.codigo,         
    cta.denominacion1,        
    cta.denominacion2,        
    mpc.mascara_numero_tarjeta,        
    ucta.eMail,        
    mpc.fecha_vencimiento,        
    'Vencidos' as flag_tipo_de_medio            
    FROM Configurations.dbo.Medio_Pago_Cuenta mpc        
    INNER JOIN configurations.dbo.Cuenta cta ON mpc.id_cuenta = cta.id_cuenta        
    INNER JOIN configurations.dbo.Usuario_Cuenta ucta ON mpc.id_cuenta = ucta.id_cuenta        
    INNER JOIN configurations.dbo.Medio_de_Pago mp ON mpc.id_medio_pago = mp.id_medio_pago        
    INNER JOIN Configurations.dbo.Estado est ON mpc.id_estado_medio_pago = est.id_estado        
    WHERE est.Codigo = 'MP_HABILITADO'        
    AND (RIGHT(mpc.fecha_vencimiento, 4) + LEFT(mpc.fecha_vencimiento, 2)) < (cast(year(getdate()) AS VARCHAR)) + RIGHT ('00' + CAST (MONTH(GETDATE()) AS VARCHAR),2)        
   UNION ALL        
   SELECT         
    mpc.id_medio_pago_cuenta,        
    mpc.id_cuenta,         
    mp.codigo,         
    cta.denominacion1,         
    cta.denominacion2,        
    mpc.mascara_numero_tarjeta,        
    utca.eMail,         
    mpc.fecha_vencimiento,         
    'AVencer' as flag_tipo_de_medio         
    FROM configurations.dbo.medio_pago_cuenta mpc        
    INNER JOIN configurations.dbo.Cuenta cta ON mpc.id_cuenta = cta.id_cuenta        
    INNER JOIN configurations.dbo.Usuario_Cuenta utca ON mpc.id_cuenta = utca.id_cuenta   
    INNER JOIN configurations.dbo.Medio_de_Pago mp ON mpc.id_medio_pago = mp.id_medio_pago        
    INNER JOIN Configurations.dbo.Estado est ON mpc.id_estado_medio_pago = est.id_estado        
    WHERE est.Codigo in ('MP_HABILITADO','MP_PEND_HABILITAR')        
    AND (RIGHT(mpc.fecha_vencimiento, 4) + LEFT(mpc.fecha_vencimiento, 2)) = (cast(year(getdate()) AS VARCHAR)) + RIGHT ('00' + CAST (MONTH(GETDATE()) AS VARCHAR),2)        
    AND mpc.medio_notificado  = 0         
   )f;        
        
           
 SET @rows = @@ROWCOUNT;          
   COMMIT TRANSACTION;              
      RETURN @rows;          
 END TRY                  
              
 BEGIN CATCH                  
   ROLLBACK TRANSACTION;                    
   RETURN 0;          
 END CATCH                  
        
END   
  
  
  
  
  
  
GO
/****** Object:  StoredProcedure [dbo].[Batch_Verificar_Control_Liquidacion_Disponible_File]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_Verificar_Control_Liquidacion_Disponible_File] @id_cuenta INT = NULL,
	@fecha_de_cashout DATE = NULL,
	@importe_disponible DECIMAL(12, 2) = NULL,
	@importe_liquidacion DECIMAL(12, 2) OUTPUT
AS
DECLARE @ret INT;
DECLARE @msg VARCHAR(MAX);

BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		SELECT @importe_liquidacion = SUM(cld.importe)
		FROM Configurations.dbo.Control_Liquidacion_Disponible cld
		WHERE cld.fecha_de_cashout = @fecha_de_cashout
			--AND cld.fecha_base_de_cashout < cast(GETDATE() as date)      
			AND cld.id_cuenta = @id_cuenta;

		IF (@importe_liquidacion = @importe_disponible)
			SET @ret = 1;
		ELSE
			SET @ret = 0;
	END TRY

	BEGIN CATCH
		SELECT @msg = ERROR_MESSAGE();

		THROW 51000,
			@msg,
			1;
	END CATCH;

	RETURN @ret;
END;

GO
/****** Object:  StoredProcedure [dbo].[Batch_VMail_Main]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Batch_VMail_Main] (@Usuario VARCHAR(20))
AS
/*Variables*/
DECLARE @v_valor INT;
DECLARE @estado_mail_pendiente INT;
DECLARE @estado_mail_vencido INT;
DECLARE @id_log_proceso INT;
DECLARE @id_proceso INT;
DECLARE @log_proceso_ok INT;
DECLARE @fecha_resultado DATETIME;
DECLARE @registros_afectados INT;

BEGIN
	SET NOCOUNT ON;

	BEGIN TRANSACTION

	BEGIN TRY
		BEGIN
			PRINT 'Comienzo del Proceso Actualizacion de Emails...'

			SELECT @id_proceso = lpo.id_proceso
			FROM Configurations.dbo.Proceso lpo
			WHERE lpo.nombre LIKE 'vencimiento de mail'

			--Iniciar Log  Proceso
			EXEC @id_log_proceso = Configurations.dbo.Iniciar_Log_Proceso @id_proceso,
				NULL,
				NULL,
				@Usuario;

			--Se recuperan los IDs de los estados requeridos
			SELECT @estado_mail_vencido = ROUND(SUM(trn.estado_vencido), 2),
				@estado_mail_pendiente = ROUND(SUM(trn.estado_pendiente), 2)
			FROM (
				SELECT id_estado AS estado_pendiente,
					0 AS estado_vencido
				FROM Configurations.dbo.Estado tmp
				WHERE tmp.codigo = 'mail_pendiente'
				
				UNION
				
				SELECT 0 AS estado_pendiente,
					id_estado AS estado_vencido
				FROM Configurations.dbo.Estado tmp
				WHERE tmp.codigo = 'mail_vencido'
				) trn

			--Se obtiene el valor del parametro
			SELECT @v_valor = cast(prm.valor AS INT)
			FROM Configurations.dbo.Parametro prm
			WHERE prm.codigo = 'MAIL_HORAS_CADUC' -- ok recuperacion del campo valor (tipo dato varchar 256)

			--Se calcula la fecha menos el parametro
			SELECT @fecha_resultado = DATEADD(HOUR, (@v_valor) * - 1, getdate());

			UPDATE Configurations.dbo.Historico_Mail_Cuenta
			SET id_estado_mail = @estado_mail_vencido,
				fecha_modificacion = GETDATE(),
				usuario_modificacion = @Usuario
			WHERE id_estado_mail = @estado_mail_pendiente
				AND fecha_alta < @fecha_resultado;

			SET @registros_afectados = @@ROWCOUNT;

			EXEC @log_proceso_ok = Configurations.dbo.Finalizar_Log_Proceso @id_log_proceso,
				@registros_afectados,
				@Usuario;
		END
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0)
			ROLLBACK TRANSACTION;

		RETURN 0;
	END CATCH

	COMMIT TRANSACTION

	RETURN 1;
END

GO
/****** Object:  StoredProcedure [dbo].[Batch_VueltaFacturacion_Actualizar]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  StoredProcedure [dbo].[Batch_VueltaFacturacion_ObtenerRegistros]    Script Date: 31/07/2015 11:48:04 ******/    
    
CREATE PROCEDURE [dbo].[Batch_VueltaFacturacion_Actualizar] (        
  @Usuario VARCHAR(20),    
  @id_log_paso INT,    
  @Cuenta INT,    
  @vuelta_facturacion varchar(15),    
  @identificador_carga_dwh INT,    
  @impuestos_reales [decimal](18, 2),     
  @tipo_comprobante char(1),    
  @numero_comprobante INT,    
  @fecha_comprobante datetime,    
  @id_item_facturacion INT,    
  @punto_venta char(1),  
  @letra_comprobante char(1)    
)    
    
AS      
      
       
    
BEGIN                
     
 SET NOCOUNT ON;          
          
 BEGIN TRY          
       
            
     BEGIN TRANSACTION;          
       
   IF (@vuelta_facturacion<>LTRIM(RTRIM('Procesado')))    
    
    BEGIN    
    
    UPDATE Configurations.dbo.Item_Facturacion     
    SET    
      vuelta_facturacion=@vuelta_facturacion,    
      id_log_vuelta_facturacion=@id_log_paso,    
      identificador_carga_dwh=@identificador_carga_dwh,    
      impuestos_reales=@impuestos_reales,    
      nro_comprobante=@numero_comprobante,    
      fecha_comprobante=@fecha_comprobante,    
      fecha_modificacion=GETDATE(),    
      usuario_modificacion=@Usuario,    
      punto_venta=@punto_venta,  
      letra_comprobante=@letra_comprobante    
    WHERE   id_cuenta=@Cuenta    
    AND     vuelta_facturacion=LTRIM(RTRIM('Pendiente'))    
       
        
    
    UPDATE Transactions.dbo.transactions                        
     SET                        
     BillingTimestamp=null,                        
     BillingStatus=0,    
     SyncStatus=0    
     WHERE id in                        
     (         
      select id_transaccion     
      from Configurations.dbo.Detalle_Facturacion dt    
      inner join Configurations.dbo.Item_Facturacion_tmp     
      tmp on dt.id_item_facturacion=@id_item_facturacion and tmp.id_cuenta=@Cuenta                   
     )    
     and BillingTimestamp is not null    
     and BillingStatus=-1    
        
   END    
    
   ELSE    
    
   BEGIN    
    
    UPDATE Configurations.dbo.Item_Facturacion     
    SET    
      vuelta_facturacion=@vuelta_facturacion,    
      id_log_vuelta_facturacion=@id_log_paso,    
      identificador_carga_dwh=@identificador_carga_dwh,    
      impuestos_reales=@impuestos_reales,    
      nro_comprobante=@numero_comprobante,    
      fecha_comprobante=@fecha_comprobante,    
      fecha_modificacion=GETDATE(),    
      usuario_modificacion=@Usuario,    
      punto_venta=@punto_venta,  
      letra_comprobante=@letra_comprobante    
    WHERE   id_cuenta=@Cuenta    
    AND     vuelta_facturacion=LTRIM(RTRIM('Pendiente'))    
    AND     tipo_comprobante=@tipo_comprobante    
    
   END    
    
    
   COMMIT TRANSACTION;          
      RETURN 1;      
     
 END TRY              
          
 BEGIN CATCH              
     
   ROLLBACK TRANSACTION;                
   RETURN 0;      
     
 END CATCH              
    
END 
GO
/****** Object:  StoredProcedure [dbo].[Batch_VueltaFacturacion_CalcularAjuste]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Batch_VueltaFacturacion_CalcularAjuste] (            
    @idCuenta INT,  
    @diferencia_ajuste decimal(18, 2),  
    @usuario VARCHAR(20)  
)  
  
AS   
   
  DECLARE @Msg varchar(20);  
  DECLARE @v_idAjuste INT;  
  DECLARE @v_idMotivoAjuste INT;  
  DECLARE @v_codigoOperacion INT;  
  DECLARE @RetCode INT  
  
  
  
     
BEGIN            
   
 SET NOCOUNT ON;            
                 
    BEGIN TRANSACTION   
   
 BEGIN TRY   
     
   IF (@diferencia_ajuste<>0)  
              
     --1.Solo realizara ajusteno cuando el valor sea positivo o negativo.  
   BEGIN  
       
     --2. Obtener el ID para tabla ajuste  
     SET @v_idAjuste = (SELECT ISNULL(MAX(id_ajuste),0) + 1 FROM Configurations.dbo.Ajuste);  
  
       
     --3.Obtener el codigo de operacion  
     SET @v_codigoOperacion = (SELECT id_codigo_operacion AS q_codigoOperacion   
             FROM Configurations.dbo.Codigo_Operacion  
             WHERE codigo_operacion=(case when @diferencia_ajuste > 0 then 'AJP' else 'AJN' end));  
  
     
     --4.Obtener el motivo del ajuste  
     SET @v_idMotivoAjuste = (SELECT id_motivo_ajuste FROM Configurations.dbo.Motivo_Ajuste WHERE codigo = 'DIF_FACT');  
       
     --5.Insertar el registro en la tabla  
     INSERT INTO [dbo].[Ajuste](  
        [id_ajuste],  
        [id_codigo_operacion],  
        [id_cuenta],  
        [id_motivo_ajuste],  
        [monto],  
        [estado_ajuste],  
        [fecha_alta],  
        [usuario_alta],  
        [version])  
      VALUES(@v_idAjuste,   
        @v_codigoOperacion,  
        @idCuenta,  
        @v_idMotivoAjuste,   
        @diferencia_ajuste,  
        'Aprobado',  
        GETDATE(),  
        @usuario,  
        0);  
        
  
           
     
   END   
     
   SET  @RetCode=1;  
   
 END TRY          
    
  BEGIN CATCH    
    
   IF (@@TRANCOUNT > 0)    
    ROLLBACK TRANSACTION;    
    SET  @RetCode=0;  
    RETURN @RetCode;  
      
    
  END CATCH  
   
 COMMIT TRANSACTION;  
   
 RETURN @RetCode;  
                
END  
GO
/****** Object:  StoredProcedure [dbo].[Batch_VueltaFacturacion_Main]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Batch_VueltaFacturacion_Main] (              
 @Usuario VARCHAR(20)    
     
        
)    
    
AS     
 /*Flags de proceso*/    
 DECLARE @Flag_OK_validaciones INT;    
 DECLARE @Flag_OK_validaciones_NOOK INT;    
 DECLARE @Flag_OK_log_proceso INT;    
 DECLARE @Flag_OK_While INT;    
 DECLARE @Flag_OK_While1 INT;    
 DECLARE @Flag_OK_While2 INT;    
 DECLARE @Flag_OK_LogPaso INT;    
      
 /*Log de proceso*/    
 DECLARE @id_proceso INT;    
 DECLARE @id_log_proceso INT;    
 DECLARE @id_log_paso INT;    
     
 /*Variables de retorno*/    
 DECLARE @Msg VARCHAR(80);    
 DECLARE @Msg_procesamiento VARCHAR(60);    
 DECLARE @RetCode INT;    
     
 /*Variables locales*/    
 DECLARE @v_cta_i INT;    
 DECLARE @v_cta_count INT;    
 DECLARE @v_Cuenta INT;    
 DECLARE @v_id_item_facturacion INT;    
 DECLARE @v_Maximo_NumeroDeCarga INT;    
 DECLARE @v_diferencia_ajuste [decimal](18, 2);    
 DECLARE @v_idTipoOrigenMovimiento INT;    
 DECLARE @v_idTipoMovimiento INT;    
 DECLARE @v_vuelta_Facturacion VARCHAR(20);    
 DECLARE @v_cantidad_procesados INT;    
 DECLARE @v_cantidad_nofacturados INT;    
 DECLARE @v_importe_procesados [decimal](18, 2);    
 DECLARE @v_importe_nofacturados [decimal](18, 2);    
 DECLARE @v_importe_total_registros [decimal](18, 2);    
 DECLARE @v_id_log_vuelta_facturacion INT;    
 DECLARE @v_identificador_carga_dwh INT;    
 DECLARE @v_impuestos_reales [decimal](18, 2);    
 DECLARE @v_tipo_comprobante CHAR(1);    
 DECLARE @v_numero_comprobante INT;    
 DECLARE @v_fecha_comprobante datetime;    
 DECLARE @v_punto_venta char(1);  
 DECLARE @v_letra_comprobante char(1);      
 DECLARE @count_mascara int    
    
    
    
    
BEGIN              
     
 SET NOCOUNT ON;              
                   
    BEGIN TRANSACTION     
     
 BEGIN TRY    
     
   PRINT 'Comienzo del Proceso Vuelta Facturacion...'    
    
   SELECT @id_proceso=lpo.id_proceso    
   FROM Configurations.dbo.Proceso lpo    
   WHERE lpo.nombre like 'Vuelta de Facturaci%'     
    
   SET @Flag_OK_validaciones_NOOK=0    
       
       
   -- 1. Iniciar Log  Proceso    
   EXEC @id_log_proceso = Configurations.dbo.Iniciar_Log_Proceso     
     @id_proceso,     
     NULL,     
     NULL,     
     @Usuario;       
    
        
      --2. Primer paso: validar acciones que permiten comenzar vuelta de facturacion    
      
  IF (@id_log_proceso is not null)    
        
    --3. Validaciones necesarias para comienzo de proceso    
    EXEC @Flag_OK_validaciones=Configurations.dbo.Batch_VueltaFacturacion_Validaciones    
      @Usuario,    
      @Msg OUTPUT;    
          
      
        
    --4. Si ingresa x aqui, es x fallo alguna de las validaciones del paso previo.    
    IF (@Flag_OK_validaciones=0 or @Msg<>'Exito')    
    
      BEGIN    
        --4.1. Finalizacion con log proceso, en caso de fallo en validaciones    
       EXEC @Flag_OK_log_proceso=Configurations.dbo.Finalizar_Log_Proceso      
         @id_log_proceso,      
         0,      
         @Usuario;    
    
       SET @Flag_OK_validaciones_NOOK=1;    
           
       PRINT @Msg;    
    
      END    
      
          ELSE    
      BEGIN    
          --4.2. Comienzo del proceso general    
                      
         EXEC  @id_log_paso=Configurations.dbo.Iniciar_Log_Paso_Proceso     
            @id_log_proceso,    
            1,    
            'Procesar ANAFACTU',    
            null,    
            @Usuario;    
            
        --5. Obtener el maximo numero de carga, utilizado para casos no facturados    
         SELECT @v_Maximo_NumeroDeCarga=max(vfMax.id_vuelta_facturacion)    
          FROM configurations.dbo.Vuelta_Facturacion vfMax    
                
         PRINT 'Carga de datos iniciales...'    
    
         --6. Carga de la tabla temporal    
         EXEC  @v_cta_count=Configurations.dbo.Batch_VueltaFacturacion_ObtenerRegistros    
            @Usuario,    
            @id_log_paso,    
            @v_Maximo_NumeroDeCarga;    
      END      
    
 END TRY            
      
 BEGIN CATCH      
      
   IF (@@TRANCOUNT > 0)      
   ROLLBACK TRANSACTION;      
   RETURN 0;    
           
    END CATCH    
     
 COMMIT TRANSACTION    
    
            
     IF (@v_cta_count<>0 or @Flag_OK_validaciones_NOOK<>1)    
                  
                   
        PRINT 'Procesamiento...'                         
                          
        SET @v_cta_i = 1;     
            
        WHILE (@v_cta_i <= @v_cta_count)      
               
         BEGIN    
               
           BEGIN TRY    
    
           BEGIN TRANSACTION    
    
           -- Asumir error    
           SET @Flag_OK_While = 0;    
    
           SELECT    
            @v_Cuenta = tmp.id_cuenta,      
            @v_id_item_facturacion = tmp.id_item_facturacion,      
            @v_diferencia_ajuste = tmp.diferencia_ajuste,    
            @v_vuelta_Facturacion=tmp.vuelta_facturacion,    
            @v_id_log_vuelta_facturacion=tmp.id_log_vuelta_facturacion,    
            @v_identificador_carga_dwh=tmp.identificador_carga_dwh,    
            @v_impuestos_reales=tmp.impuestos_reales,    
            @v_tipo_comprobante=tmp.tipo_comprobante,    
            @v_numero_comprobante=tmp.nro_comprobante,    
            @v_fecha_comprobante=tmp.fecha_comprobante,    
            @v_punto_venta=tmp.mascara,  
            @v_letra_comprobante=tmp.letra_comprobante    
            FROM Configurations.dbo.Item_Facturacion_tmp tmp     
            WHERE tmp.i = @v_cta_i;    
                
                              
                
            IF (@v_vuelta_Facturacion='Procesado')    
                 
             BEGIN    
                   
                                                       
              EXEC @Flag_OK_While = Configurations.dbo.Batch_VueltaFacturacion_CalcularAjuste     
                @v_Cuenta,      
                @v_diferencia_ajuste,      
                @Usuario;    
                 
              IF (@Flag_OK_While=1 and @v_diferencia_ajuste<>0)    
    
               BEGIN    
                                  
                 SET @v_idTipoMovimiento = (SELECT tpo.id_tipo FROM configurations.dbo.Tipo tpo WHERE tpo.codigo = 'MOV_CRED' AND tpo.id_grupo_tipo = 16 AND @v_diferencia_ajuste > 0    
                    UNION ALL    
                        SELECT tpo.id_tipo FROM configurations.dbo.Tipo tpo WHERE tpo.codigo = 'MOV_DEB' AND tpo.id_grupo_tipo = 16 AND @v_diferencia_ajuste < 0);    
             
                 SET @v_idTipoOrigenMovimiento = (SELECT tpo.id_tipo FROM configurations.dbo.Tipo tpo WHERE tpo.codigo = 'ORIG_PROCESO' AND tpo.id_grupo_tipo = 17);    
                  
                                             
                              
                 EXECUTE @Flag_OK_While1=Configurations.dbo.Actualizar_Cuenta_Virtual     
                   @v_diferencia_ajuste,     
                   null,     
                   @v_diferencia_ajuste,     
                   null,     
                   null,    
                   null,    
                   @v_Cuenta,    
                   @Usuario,     
                   @v_idTipoMovimiento,     
                   @v_idTipoOrigenMovimiento,     
                   @id_log_proceso;    
                END    
                           END    
    
                    
            EXECUTE @Flag_OK_While2=Configurations.dbo.Batch_VueltaFacturacion_Actualizar    
              @Usuario,    
              @id_log_paso,    
              @v_Cuenta,    
              @v_vuelta_Facturacion,    
              @v_identificador_carga_dwh,    
              @v_impuestos_reales,    
              @v_tipo_comprobante,    
              @v_numero_comprobante,    
              @v_fecha_comprobante,    
              @v_id_item_facturacion,    
              @v_punto_venta,  
              @v_letra_comprobante;    
                 
                 
           COMMIT TRANSACTION;    
    
           END TRY    
    
           BEGIN CATCH    
                             
             SET @Msg_procesamiento='Se ha producido un fallo en el procesamiento de la cuenta'    
             PRINT @Msg_procesamiento;    
             PRINT @v_Cuenta;    
               
           END CATCH    
               
               
           -- Incrementar contador    
            SET @v_cta_i += 1;     
               
           END    
                      
        IF (@Flag_OK_validaciones_NOOK<>1)    
                      
             BEGIN TRY    
    
             BEGIN TRANSACTION    
               
             PRINT 'Reporte final de datos...'    
                      
             SELECT @v_cantidad_procesados=isnull(COUNT(tmp.id_cuenta),0) from Configurations.dbo.Item_Facturacion tmp where tmp.vuelta_facturacion=LTRIM(RTRIM('Procesado')) and tmp.id_log_vuelta_facturacion=@id_log_paso    
             SELECT @v_cantidad_nofacturados=isnull(COUNT(tmp.id_cuenta),0) from Configurations.dbo.Item_Facturacion tmp where tmp.vuelta_facturacion=LTRIM(RTRIM('No Facturado')) and tmp.id_log_vuelta_facturacion=@id_log_paso    
             SELECT @v_importe_procesados=isnull(SUM(tmp.suma_cargos),0) from Configurations.dbo.Item_Facturacion tmp where tmp.vuelta_facturacion=LTRIM(RTRIM('Procesado')) and tmp.id_log_vuelta_facturacion=@id_log_paso    
             SELECT @v_importe_nofacturados=isnull(SUM(tmp.suma_cargos),0) from Configurations.dbo.Item_Facturacion tmp where tmp.vuelta_facturacion=LTRIM(RTRIM('No Facturado')) and tmp.id_log_vuelta_facturacion=@id_log_paso    
             SELECT @v_importe_total_registros=isnull(@v_importe_procesados+@v_importe_nofacturados,0)    
    
             BEGIN    
    
             EXEC  @Flag_OK_LogPaso=Configurations.dbo.Finalizar_Log_Paso_Proceso    
               @id_log_paso,    
               null,    
               1,    
               null,    
               @v_cta_count,    
               @v_importe_total_registros,    
               @v_cantidad_procesados,    
               @v_importe_procesados,    
               @v_cantidad_nofacturados,    
               @v_importe_nofacturados,    
               null,    
               null,    
               @Usuario;    
             END    
             
               
             BEGIN    
         
                EXEC @Flag_OK_log_proceso=Configurations.dbo.Finalizar_Log_Proceso      
                @id_log_proceso,      
                0,      
                @Usuario;    
             END    
             
             COMMIT TRANSACTION;    
    
             END TRY    
    
             BEGIN CATCH    
               SET @Flag_OK_While = 0;    
               SET @Msg_procesamiento='Se ha producido un fallo reporte final'    
               PRINT @Msg_procesamiento    
             END CATCH    
             
             PRINT 'Fin del Proceso Vuelta Facturacion...'     
                 
             RETURN 1;      
                         
                        
END 
GO
/****** Object:  StoredProcedure [dbo].[Batch_VueltaFacturacion_ObtenerRegistros]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
    
/****** Object:  StoredProcedure [dbo].[Batch_VueltaFacturacion_ObtenerRegistros]    Script Date: 31/07/2015 11:48:04 ******/      
      
CREATE PROCEDURE [dbo].[Batch_VueltaFacturacion_ObtenerRegistros] (          
  @Usuario VARCHAR(20),      
  @id_log_paso INT,      
  @Maximo_NumeroDeCarga INT      
        
      
)      
      
AS        
  DECLARE @rows INT;        
  DECLARE @I INT;              
        
      
BEGIN                  
 SET NOCOUNT ON;            
            
 BEGIN TRY            
  TRUNCATE TABLE Configurations.dbo.Item_Facturacion_tmp;            
              
  BEGIN TRANSACTION;            
             
  INSERT INTO [dbo].[Item_Facturacion_tmp] (      
   [I],      
   [id_item_facturacion],      
   [id_cuenta],      
   [cuenta_aurus],      
   [suma_cargos],      
   [suma_impuestos],      
   [diferencia_ajuste],      
   [vuelta_facturacion],      
   [id_log_vuelta_facturacion],      
   [identificador_carga_dwh],      
   [impuestos_reales],      
   [tipo_comprobante],      
   [nro_comprobante],      
   [fecha_comprobante],      
   [Mascara],      
   [fecha_alta],      
   [usuario_alta],  
   [letra_comprobante]        
   )      
  SELECT ROW_NUMBER() OVER (      
    ORDER BY id_cuenta      
    ) AS I,      
   f.[id_item_facturacion],      
   f.[id_cuenta],      
   f.[cuenta_aurus],      
   f.[suma_cargos],      
   f.[suma_impuestos],      
   f.[diferencia_ajuste],      
   f.[vuelta_facturacion],      
   f.[id_log_vuelta_facturacion],      
   f.[id_vuelta_facturacion],      
   f.[Importe_pesos_iva],      
   f.[tipo_comprobante],      
   f.[nro_comprobante],      
   f.[fecha_comprobante],      
   f.[Mascara],      
   f.[fecha_alta],      
   f.[usuario_alta],  
   f.[letra_comprobante]       
  FROM (      
   SELECT  top 1    
    tif.id_item_facturacion,      
    tif.id_cuenta,      
    tif.cuenta_aurus,      
    isnull(tif.suma_cargos,0) AS suma_cargos,      
    isnull(tif.suma_impuestos,0) AS suma_impuestos,      
    isnull((tif.suma_impuestos - vf.Importe_pesos_iva),0) AS diferencia_ajuste,      
    'Procesado' AS vuelta_facturacion,      
    @id_log_paso AS id_log_vuelta_facturacion,      
    vf.id_vuelta_facturacion,      
    isnull(vf.Importe_pesos_iva,0) AS Importe_pesos_iva,      
    vf.Tipo_comprobante,      
    vf.Nro_comprobante,      
    vf.Fecha_comprobante,      
    vf.Mascara,      
    tif.fecha_alta,      
    tif.usuario_alta,  
    vf.letra_comprobante         
   FROM configurations.dbo.Item_Facturacion tif      
   INNER JOIN configurations.dbo.Vuelta_Facturacion vf      
    ON tif.cuenta_aurus = convert(int,vf.Nro_cliente_ext)      
    and tif.tipo_comprobante=vf.Tipo_comprobante      
    and tif.suma_cargos_aurus=case when tif.tipo_comprobante='F' then cast(vf.Importe_pesos as numeric(12,2)) else cast(isnull(vf.Importe_pesos,0)*-1 as decimal(12,2)) END      
   WHERE tif.vuelta_facturacion = 'Pendiente'      
    AND tif.id_log_vuelta_facturacion IS NULL      
    AND tif.identificador_carga_dwh IS NULL      
    AND vf.Mascara<=3      
    AND vf.id_vuelta_facturacion = (      
     SELECT max(vfMax.id_vuelta_facturacion)      
     FROM configurations.dbo.Vuelta_Facturacion vfMax      
     )      
       
   UNION ALL      
   SELECT   top 1    
       tif.id_item_facturacion,      
    tif.id_cuenta,      
    NULL AS cuenta_aurus,      
    NULL AS suma_cargos,      
    NULL AS suma_impuestos,      
    NULL AS diferencia_ajuste,      
    'No Facturado' AS vuelta_facturacion,      
    @id_log_paso AS id_log_vuelta_facturacion,      
    @Maximo_NumeroDeCarga AS id_vuelta_facturacion,      
    NULL AS Importe_pesos_iva,      
    NULL AS tipo_comprobante,      
    NULL AS Nro_comprobante,      
    NULL AS Fecha_comprobante,      
    NULL AS Mascara,      
    tif.fecha_alta,      
    tif.usuario_alta,  
    null AS letra_comprobante      
   FROM configurations.dbo.Item_Facturacion tif      
   where not exists (      
   select 1      
   from configurations.dbo.Vuelta_Facturacion vf      
    where tif.cuenta_aurus = convert(int,vf.Nro_cliente_ext)      
    and tif.tipo_comprobante=vf.Tipo_comprobante      
    and tif.suma_cargos_aurus=case when tif.tipo_comprobante='F' then cast(vf.Importe_pesos as numeric(12,2))       
    else cast(isnull(vf.Importe_pesos,0)*-1 as decimal(12,2)) END)      
    AND  tif.vuelta_facturacion = 'Pendiente'      
    AND tif.id_log_vuelta_facturacion IS NULL      
    AND tif.identificador_carga_dwh IS NULL      
   ) f;      
      
          
        
 SET @rows = @@ROWCOUNT;        
   COMMIT TRANSACTION;            
      RETURN @rows;        
 END TRY                
            
 BEGIN CATCH                
   ROLLBACK TRANSACTION;             
   RETURN 0;        
 END CATCH                
      
END 
GO
/****** Object:  StoredProcedure [dbo].[Batch_VueltaFacturacion_Validaciones]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
    
CREATE PROCEDURE [dbo].[Batch_VueltaFacturacion_Validaciones] (            
 @Usuario VARCHAR(20),  
 @Msg VARCHAR(80) OUTPUT  
   
    
)  
  
AS   
   
 DECLARE @RetCode INT;  
 DECLARE @CantidadRegistros_Vuelta INT;  
 DECLARE @CantidadRegistros_Pendientes INT;  
 DECLARE @Maximo_NumeroDeCarga INT  
  
    
BEGIN            
   
 SET NOCOUNT ON;            
                 
    BEGIN TRANSACTION   
   
 BEGIN TRY   
   
  SELECT @CantidadRegistros_Vuelta=COUNT(Nro_Item)   
  FROM Configurations.dbo.Vuelta_facturacion  
    
  IF (@CantidadRegistros_Vuelta<=0)  
     
   BEGIN    
    SET  @RetCode=0;  
    SET  @Msg='No existen registros en la tabla vuelta de facturacion - AURUS'  
   END    
    
  ELSE      
      
    SELECT @CantidadRegistros_Pendientes=count(id_cuenta)   
        FROM configurations.dbo.Item_Facturacion tif  
        WHERE tif.vuelta_facturacion = 'Pendiente'  
          AND   tif.id_log_vuelta_facturacion  IS NULL  
      AND   tif.identificador_carga_dwh IS NULL  
      
    IF(@CantidadRegistros_Pendientes=0)  
     BEGIN  
       SET  @RetCode = 0;   
       SET  @Msg='No existen registros en estado pendiente en la tabla item facturacion'  
     END  
      
    ELSE  
       
     BEGIN  
        
      SELECT @Maximo_NumeroDeCarga=MAX(t.premaximo)FROM  
      (SELECT m.maximo AS premaximo  
      FROM (SELECT MAX(Id_Vuelta_Facturacion) AS maximo  
      FROM configurations.dbo.Vuelta_Facturacion) m  
      WHERE m.maximo IN   
      (SELECT identificador_carga_dwh FROM configurations.dbo.Item_Facturacion)  
      UNION ALL  
      SELECT -1 AS premaximo) t  
  
      IF (@Maximo_NumeroDeCarga<>-1)  
  
       BEGIN  
        SET  @RetCode = 0;   
        SET  @Msg='Se ha detectado que el maximo id de carga ha sido procesado'  
       END  
      ELSE  
       BEGIN  
        SET  @RetCode = 1;  
        SET  @Msg='Exito'  
       END  
      END  
 END TRY          
    
  BEGIN CATCH    
    
   IF (@@TRANCOUNT > 0)    
    ROLLBACK TRANSACTION;    
   RETURN @RetCode;  
   RETURN @Msg;  
     
    
  END CATCH  
   
 COMMIT TRANSACTION  
   
 RETURN @RetCode;  
 RETURN @Msg;  
   
               
END  
GO
/****** Object:  StoredProcedure [dbo].[Facturacion_Actualizar_Procesados]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Facturacion_Actualizar_Procesados] (
	@fecha_finProceso DATETIME = NULL,
	@v_id_cuenta INT = NULL
	)
AS
DECLARE @CodRet INT

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRANSACTION

BEGIN TRY
	BEGIN
		UPDATE transactions.dbo.transactions
		SET BillingTimestamp = GETDATE(),
			BillingStatus = - 1,
			SyncStatus = 0
		WHERE LiquidationStatus = - 1
			AND LiquidationTimestamp IS NOT NULL
			AND BillingStatus <> - 1
			AND BillingTimestamp IS NULL
			AND CreateTimestamp <= @fecha_finProceso
			AND LocationIdentification = @v_id_cuenta
			AND id IN (
				SELECT id
				FROM Configurations.dbo.Procesar_Facturacion_tmp
				)
	END

	COMMIT TRANSACTION;

	SET @CodRet = 1;
END TRY

BEGIN CATCH
	IF (@@TRANCOUNT > 0)
		ROLLBACK TRANSACTION;

	SET @CodRet = 0;

	RETURN @CodRet;
END CATCH

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

RETURN @CodRet;

GO
/****** Object:  StoredProcedure [dbo].[Facturacion_Calcular_Compras]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Facturacion_Calcular_Compras] (
	@v_id_log_facturacion INT = NULL,
	@v_id_ciclo_facturacion INT = NULL,
	@v_tipo CHAR(3) = NULL,
	@v_concepto CHAR(3) = NULL,
	@v_subconcepto CHAR(3) = NULL,
	@v_id_cuenta INT = NULL,
	@v_anio INT = NULL,
	@v_mes INT = NULL,
	@v_vuelta_facturacion VARCHAR(15) = NULL,
	@v_usuario_alta VARCHAR(20) = NULL,
	@v_version INT = NULL,
	@v_cuenta_aurus INT = NULL,
	@fecha_finProceso DATETIME = NULL
	)
AS
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

DECLARE @v_cantidad_registros INT;
DECLARE @v_suma_cargos DECIMAL(12, 2);
DECLARE @suma_cargos_aurus DECIMAL(12, 2)
DECLARE @v_suma_impuestos DECIMAL(12, 2);
DECLARE @v_suma_cargos_dev DECIMAL(12, 2);
DECLARE @suma_cargos_aurus_dev DECIMAL(12, 2)
DECLARE @v_suma_impuestos_dev DECIMAL(12, 2);
DECLARE @v_tax_amount DECIMAL(12, 2);
DECLARE @v_id_item_facturacion INT;
DECLARE @v_fecha_actual DATETIME;
DECLARE @fecha_minima DATETIME;
DECLARE @CodRet INT

BEGIN TRANSACTION

BEGIN TRY
	BEGIN
		SELECT @v_id_item_facturacion = ISNULL(MAX(ifo.id_item_facturacion), 0) + 1,
			@v_fecha_actual = GETDATE()
		FROM Configurations.dbo.Item_Facturacion ifo;

		SELECT @v_suma_cargos = SUM(ISNULL(pf.FeeAmount, 0)),
			@v_suma_impuestos = SUM(ISNULL(pf.TaxAmount, 0)),
			@suma_cargos_aurus = SUM(CASE 
					WHEN pf.TaxAmount = 0
						THEN cast(isnull(pf.FeeAmount, 0) / 1.21 AS DECIMAL(12, 2))
					ELSE pf.FeeAmount
					END),
			@v_cantidad_registros = count(I)
		FROM Configurations.dbo.Procesar_Facturacion_tmp pf
		WHERE LTRIM(RTRIM(pf.OperationName)) IN (
				'Compra_offline',
				'Compra_online'
				)
			AND pf.LocationIdentification = @v_id_cuenta;

		SELECT @fecha_minima = MIN(CreateTimestamp)
		FROM Configurations.dbo.Procesar_Facturacion_tmp pf
		WHERE LTRIM(RTRIM(pf.OperationName)) IN (
				'Compra_offline',
				'Compra_online'
				)
			AND pf.LocationIdentification = @v_id_cuenta;
	END

	IF (
			@v_suma_cargos > 0
			AND @v_cantidad_registros > 0
			)
	BEGIN
		INSERT INTO [dbo].[Item_Facturacion] (
			[id_item_facturacion],
			[id_log_facturacion],
			[id_ciclo_facturacion],
			[tipo],
			[concepto],
			[subconcepto],
			[id_cuenta],
			[anio],
			[mes],
			[suma_cargos],
			[suma_impuestos],
			[vuelta_facturacion],
			[tipo_comprobante],
			[fecha_alta],
			[usuario_alta],
			[version],
			[cuenta_aurus],
			[suma_cargos_aurus],
			[fecha_desde_proceso],
			[fecha_hasta_proceso]
			)
		VALUES (
			@v_id_item_facturacion,
			@v_id_log_facturacion,
			@v_id_ciclo_facturacion,
			@v_tipo,
			@v_concepto,
			@v_subconcepto,
			@v_id_cuenta,
			@v_anio,
			@v_mes,
			@v_suma_cargos,
			@v_suma_impuestos,
			@v_vuelta_facturacion,
			'F',
			@v_fecha_actual,
			@v_usuario_alta,
			@v_version,
			@v_cuenta_aurus,
			@suma_cargos_aurus,
			@fecha_minima,
			@fecha_finProceso
			);

		--Detalle del Item                
		INSERT INTO [dbo].[Detalle_Facturacion] (
			[id_item_facturacion],
			[id_transaccion],
			[fecha_alta],
			[usuario_alta],
			[version]
			)
		SELECT @v_id_item_facturacion,
			txs.Id,
			@v_fecha_actual,
			@v_usuario_alta,
			@v_version
		FROM Configurations.dbo.Procesar_Facturacion_tmp txs
		WHERE LTRIM(RTRIM(txs.OperationName)) IN (
				'Compra_offline',
				'Compra_online'
				)
			AND txs.LiquidationStatus = - 1
			AND txs.LiquidationTimestamp IS NOT NULL
			AND txs.BillingStatus <> - 1
			AND txs.BillingTimestamp IS NULL
			AND txs.CreateTimestamp <= @fecha_finProceso
			AND txs.LocationIdentification = @v_id_cuenta;
	END

	COMMIT TRANSACTION;

	SET @CodRet = 1;
END TRY

BEGIN CATCH
	IF (@@TRANCOUNT > 0)
		ROLLBACK TRANSACTION;

	SET @CodRet = 0;

	RETURN @CodRet;
END CATCH

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

RETURN @CodRet;

GO
/****** Object:  StoredProcedure [dbo].[Facturacion_Calcular_Dev]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Facturacion_Calcular_Dev] (
	@v_id_log_facturacion INT = NULL,
	@v_id_ciclo_facturacion INT = NULL,
	@v_tipo CHAR(3) = NULL,
	@v_concepto CHAR(3) = NULL,
	@v_subconcepto CHAR(3) = NULL,
	@v_id_cuenta INT = NULL,
	@v_anio INT = NULL,
	@v_mes INT = NULL,
	@v_vuelta_facturacion VARCHAR(15) = NULL,
	@v_usuario_alta VARCHAR(20) = NULL,
	@v_version INT = NULL,
	@v_cuenta_aurus INT = NULL,
	@fecha_finProceso DATETIME = NULL
	)
AS
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

DECLARE @v_cantidad_registros INT;
DECLARE @v_suma_cargos DECIMAL(12, 2);
DECLARE @suma_cargos_aurus DECIMAL(12, 2)
DECLARE @v_suma_impuestos DECIMAL(12, 2);
DECLARE @v_suma_cargos_dev DECIMAL(12, 2);
DECLARE @suma_cargos_aurus_dev DECIMAL(12, 2)
DECLARE @v_suma_impuestos_dev DECIMAL(12, 2);
DECLARE @v_tax_amount DECIMAL(12, 2);
DECLARE @v_id_item_facturacion INT;
DECLARE @v_fecha_actual DATETIME;
DECLARE @fecha_minima DATETIME;
DECLARE @CodRet INT

BEGIN TRANSACTION

BEGIN TRY
	BEGIN
		SELECT @v_id_item_facturacion = ISNULL(MAX(ifo.id_item_facturacion), 0) + 1,
			@v_fecha_actual = GETDATE()
		FROM Configurations.dbo.Item_Facturacion ifo;

		SELECT @v_suma_cargos = SUM(ISNULL(pf.FeeAmount, 0)),
			@v_suma_impuestos = SUM(ISNULL(pf.TaxAmount, 0)),
			@suma_cargos_aurus = SUM(CASE 
					WHEN pf.TaxAmount = 0
						THEN cast(isnull(pf.FeeAmount, 0) / 1.21 AS DECIMAL(12, 2))
					ELSE pf.FeeAmount
					END),
			@v_cantidad_registros = count(I)
		FROM Configurations.dbo.Procesar_Facturacion_tmp pf
		WHERE LTRIM(RTRIM(pf.OperationName)) IN ('Devolucion')
			AND pf.LocationIdentification = @v_id_cuenta;

		SELECT @fecha_minima = MIN(CreateTimestamp)
		FROM Configurations.dbo.Procesar_Facturacion_tmp pf
		WHERE LTRIM(RTRIM(pf.OperationName)) IN ('Devolucion')
			AND pf.LocationIdentification = @v_id_cuenta
	END

	IF (
			@v_suma_cargos > 0
			AND @v_cantidad_registros > 0
			)
	BEGIN
		INSERT INTO [dbo].[Item_Facturacion] (
			[id_item_facturacion],
			[id_log_facturacion],
			[id_ciclo_facturacion],
			[tipo],
			[concepto],
			[subconcepto],
			[id_cuenta],
			[anio],
			[mes],
			[suma_cargos],
			[suma_impuestos],
			[vuelta_facturacion],
			[tipo_comprobante],
			[fecha_alta],
			[usuario_alta],
			[version],
			[cuenta_aurus],
			[suma_cargos_aurus],
			[fecha_desde_proceso],
			[fecha_hasta_proceso]
			)
		VALUES (
			@v_id_item_facturacion,
			@v_id_log_facturacion,
			@v_id_ciclo_facturacion,
			@v_tipo,
			@v_concepto,
			@v_subconcepto,
			@v_id_cuenta,
			@v_anio,
			@v_mes,
			@v_suma_cargos,
			@v_suma_impuestos,
			@v_vuelta_facturacion,
			'C',
			@v_fecha_actual,
			@v_usuario_alta,
			@v_version,
			@v_cuenta_aurus,
			@suma_cargos_aurus,
			@fecha_minima,
			@fecha_finProceso
			);

		--Detalle del Item                
		INSERT INTO [dbo].[Detalle_Facturacion] (
			[id_item_facturacion],
			[id_transaccion],
			[fecha_alta],
			[usuario_alta],
			[version]
			)
		SELECT @v_id_item_facturacion,
			txs.Id,
			@v_fecha_actual,
			@v_usuario_alta,
			@v_version
		FROM Configurations.dbo.Procesar_Facturacion_tmp txs
		WHERE LTRIM(RTRIM(txs.OperationName)) IN ('Devolucion')
			AND txs.LiquidationStatus = - 1
			AND txs.LiquidationTimestamp IS NOT NULL
			AND txs.BillingStatus <> - 1
			AND txs.BillingTimestamp IS NULL
			AND txs.CreateTimestamp <= @fecha_finProceso
			AND txs.LocationIdentification = @v_id_cuenta;
	END

	COMMIT TRANSACTION;

	SET @CodRet = 1;
END TRY

BEGIN CATCH
	IF (@@TRANCOUNT > 0)
		ROLLBACK TRANSACTION;

	SET @CodRet = 0;

	RETURN @CodRet;
END CATCH

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

RETURN @CodRet;

GO
/****** Object:  StoredProcedure [dbo].[Facturacion_Liquidacion_CargaCuentas]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  StoredProcedure [dbo].[Batch_VueltaFacturacion_ObtenerRegistros]    Script Date: 31/07/2015 11:48:04 ******/
CREATE PROCEDURE [dbo].[Facturacion_Liquidacion_CargaCuentas] (
	@fecha_inicio_proceso DATE = NULL,
	@fecha_fin_proceso DATE = NULL,
	@Usuario VARCHAR(20)
	)
AS
DECLARE @rows INT;

BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		TRUNCATE TABLE Configurations.dbo.Control_Liquidacion_Facturacion;

		BEGIN TRANSACTION;

		INSERT INTO [dbo].[Control_Liquidacion_Facturacion] (
			[id_cuenta],
			[total_liquidado],
			[tipo_comprobante_liqui],
			[fecha_alta],
			[usuario_alta]
			)
		SELECT f.[id_cuenta],
			f.[MontoCalculado],
			f.[tipo_comprobante_liqui],
			f.[fecha_alta],
			f.[usuario_alta]
		FROM (
			SELECT tr.LocationIdentification AS id_cuenta,
				sum(monto_calculado) AS MontoCalculado,
				'F' AS tipo_comprobante_liqui,
				getdate() AS fecha_alta,
				@Usuario AS usuario_alta
			FROM Configurations.dbo.Cargos_Por_Transaccion cxt
			INNER JOIN Transactions.dbo.transactions tr
				ON cxt.id_transaccion = tr.Id
					AND LTRIM(RTRIM(tr.OperationName)) IN (
						'Compra_offline',
						'Compra_online'
						)
					AND tr.CreateTimestamp >= @fecha_inicio_proceso
					AND tr.CreateTimestamp <= @fecha_fin_proceso
			GROUP BY tr.LocationIdentification
			
			UNION
			
			SELECT tr.LocationIdentification AS id_cuenta,
				sum(monto_calculado) AS MontoCalculado,
				'C' AS tipo_comprobante_liqui,
				getdate() AS fecha_alta,
				@Usuario AS usuario_alta
			FROM Configurations.dbo.Cargos_Por_Transaccion cxt
			INNER JOIN Transactions.dbo.transactions tr
				ON cxt.id_transaccion = tr.Id
					AND LTRIM(RTRIM(tr.OperationName)) IN ('Devolucion')
					AND tr.CreateTimestamp >= @fecha_inicio_proceso
					AND tr.CreateTimestamp <= @fecha_fin_proceso
			GROUP BY tr.LocationIdentification
			) f;

		SET @rows = @@ROWCOUNT;

		COMMIT TRANSACTION;

		RETURN @rows;
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION;

		RETURN 0;
	END CATCH
END

GO
/****** Object:  StoredProcedure [dbo].[Facturacion_Liquidacion_CargaItems]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  StoredProcedure [dbo].[Batch_VueltaFacturacion_ObtenerRegistros]    Script Date: 31/07/2015 11:48:04 ******/
CREATE PROCEDURE [dbo].[Facturacion_Liquidacion_CargaItems] (
	@fecha_inicio_proceso DATE = NULL,
	@fecha_fin_proceso DATE = NULL,
	@Usuario VARCHAR(20),
	@Id_log_paso INT = NULL
	)
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRANSACTION;

		MERGE Configurations.dbo.Control_Liquidacion_Facturacion AS Destino
		USING (
			SELECT itf.id_cuenta,
				itf.tipo_comprobante,
				itf.suma_cargos_aurus
			FROM Configurations.dbo.Item_Facturacion itf
			WHERE cast(itf.fecha_alta AS DATE) = cast(getdate() AS DATE)
				AND itf.vuelta_facturacion = 'Pendiente'
				AND itf.id_log_facturacion = @Id_log_paso
			) AS Origen
			ON (
					Origen.id_cuenta = Destino.id_cuenta
					AND Origen.tipo_comprobante = Destino.tipo_comprobante_liqui
					)
		WHEN MATCHED
			THEN
				UPDATE
				SET Destino.suma_cargos_aurus = Origen.suma_cargos_aurus,
					Destino.tipo_comprobante_fact = Origen.tipo_comprobante,
					Destino.fecha_modificacion = getdate(),
					Destino.usuario_modificacion = @Usuario
		WHEN NOT MATCHED
			THEN
				INSERT (
					id_cuenta,
					suma_cargos_aurus,
					tipo_comprobante_fact,
					fecha_alta,
					usuario_alta
					)
				VALUES (
					Origen.id_cuenta,
					Origen.suma_cargos_aurus,
					Origen.tipo_comprobante,
					getdate(),
					@Usuario
					);

		COMMIT TRANSACTION;

		RETURN 1;
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION;

		RETURN 0;
	END CATCH
END

GO
/****** Object:  StoredProcedure [dbo].[Facturacion_Liquidacion_CargaSaldos]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  StoredProcedure [dbo].[Batch_VueltaFacturacion_ObtenerRegistros]    Script Date: 31/07/2015 11:48:04 ******/
CREATE PROCEDURE [dbo].[Facturacion_Liquidacion_CargaSaldos] (
	@I_control INT = NULL,
	@id_cuenta INT = NULL,
	@fecha_inicio_proceso DATE = NULL,
	@fecha_fin_proceso DATE = NULL,
	@v_suma_cargos_aurus DECIMAL(12, 2) = NULL,
	@v_total_liquidado DECIMAL(12, 2) = NULL,
	@Usuario VARCHAR(20),
	@Mes INT = NULL,
	@Anio INT = NULL,
	@IdCicloFacturacion INT = NULL
	)
AS
--Variables del proceso          
DECLARE @v_numero_cuit VARCHAR(11);
DECLARE @v_eMail VARCHAR(50);
DECLARE @v_saldo_pendiente DECIMAL(18, 2);
DECLARE @v_saldo_revision DECIMAL(18, 2);
DECLARE @v_saldo_disponible DECIMAL(18, 2);
DECLARE @v_posee_diferencia BIT;

BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRANSACTION;

		-- Obtener CUIT y email de la Cuenta          
		SELECT @v_numero_cuit = (
				CASE 
					WHEN ltrim(rtrim(tpo.codigo)) = 'CTA_PROFESIONAL'
						AND ltrim(rtrim(tpo.codigo)) <> 'IVA_CONS_FINAL'
						THEN isnull(cta.numero_CUIT, '0')
					WHEN ltrim(rtrim(tpo.codigo)) = 'CTA_EMPRESA'
						THEN isnull(sfc.numero_CUIT, 0)
					ELSE isnull(cta.numero_identificacion, '0')
					END
				),
			@v_eMail = uscta.eMail
		FROM Configurations.dbo.Cuenta cta
		INNER JOIN Configurations.dbo.Situacion_Fiscal_Cuenta sfc
			ON sfc.id_cuenta = cta.id_cuenta
		INNER JOIN Configurations.dbo.Tipo tpo
			ON cta.id_tipo_cuenta = tpo.id_tipo
		INNER JOIN Configurations.dbo.Usuario_Cuenta uscta
			ON uscta.id_cuenta = cta.id_cuenta
		WHERE cta.id_cuenta = @id_cuenta
			AND sfc.flag_vigente = 1
			AND uscta.fecha_baja IS NULL
			AND uscta.usuario_baja IS NULL;

		-- Obtener Saldos          
		SELECT TOP 1 @v_saldo_pendiente = lmcv.saldo_cuenta_actual,
			@v_saldo_revision = lmcv.saldo_revision_actual,
			@v_saldo_disponible = lmcv.disponible_actual
		FROM Configurations.dbo.Log_Movimiento_Cuenta_Virtual lmcv
		WHERE cast(lmcv.fecha_alta AS DATE) BETWEEN cast(@fecha_inicio_proceso AS DATE)
				AND cast(@fecha_fin_proceso AS DATE)
			AND lmcv.id_cuenta = @id_cuenta
		ORDER BY lmcv.fecha_alta DESC;

		-- Actualizar temporal          
		UPDATE Configurations.dbo.Control_Liquidacion_Facturacion
		SET numero_CUIT = @v_numero_cuit,
			eMail = @v_eMail,
			saldo_pendiente = @v_saldo_pendiente,
			saldo_revision = @v_saldo_revision,
			saldo_disponible = @v_saldo_disponible,
			id_ciclo_facturacion = @IdCicloFacturacion,
			mes = @Mes,
			anio = @Anio,
			posee_diferencia = (
				CASE 
					WHEN (
							@v_suma_cargos_aurus <> @v_total_liquidado
							OR @v_suma_cargos_aurus IS NULL
							OR @v_total_liquidado IS NULL
							)
						THEN 1
					ELSE 0
					END
				),
			fecha_modificacion = getdate(),
			usuario_modificacion = @Usuario
		WHERE id_cuenta = @id_cuenta
			AND I_control = @I_control;

		COMMIT TRANSACTION;

		RETURN 1;
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION;

		RETURN 0;
	END CATCH
END

GO
/****** Object:  StoredProcedure [dbo].[Facturacion_Liquidacion_Main]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Facturacion_Liquidacion_Main] (
	@fecha_inicio_proceso DATE = NULL,
	@fecha_fin_proceso DATE = NULL,
	@Usuario VARCHAR(20),
	@Id_log_paso INT = NULL,
	@Mes INT = NULL,
	@Anio INT = NULL,
	@IdCicloFacturacion INT = NULL
	)
AS
DECLARE @v_cta_i INT;
DECLARE @v_cta_count INT;
DECLARE @v_items_result INT;
DECLARE @v_saldos_result INT;
DECLARE @v_I_control INT;
DECLARE @v_id_cuenta INT;
DECLARE @v_suma_cargos_aurus DECIMAL(12, 2);
DECLARE @v_total_liquidado DECIMAL(12, 2);
DECLARE @total_diferencias INT;
DECLARE @total_tabla_items INT;

BEGIN
	SET NOCOUNT ON;

	BEGIN TRANSACTION

	BEGIN TRY
		BEGIN
			EXEC @v_cta_count = Configurations.dbo.Facturacion_Liquidacion_CargaCuentas @fecha_inicio_proceso,
				@fecha_fin_proceso,
				@Usuario;
		END

		BEGIN
			EXEC @v_items_result = Configurations.dbo.Facturacion_Liquidacion_CargaItems @fecha_inicio_proceso,
				@fecha_fin_proceso,
				@Usuario,
				@Id_log_paso;
		END

		COMMIT TRANSACTION;
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0)
			ROLLBACK TRANSACTION;

		RETURN 0;
	END CATCH
END

IF (
		@v_cta_count <> 0
		AND @v_items_result <> 0
		)
	SET @v_cta_i = 1;

SELECT @total_tabla_items = MAX(clf.I_control)
FROM configurations.dbo.Control_Liquidacion_Facturacion clf

WHILE (@v_cta_i <= @total_tabla_items)
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION

		SELECT @v_I_control = tmp.I_control,
			@v_id_cuenta = tmp.id_cuenta,
			@v_suma_cargos_aurus = tmp.suma_cargos_aurus,
			@v_total_liquidado = tmp.total_liquidado
		FROM Configurations.dbo.Control_Liquidacion_Facturacion tmp
		WHERE tmp.I_control = @v_cta_i;

		BEGIN
			EXEC @v_saldos_result = Configurations.dbo.Facturacion_Liquidacion_CargaSaldos @v_I_control,
				@v_id_cuenta,
				@fecha_inicio_proceso,
				@fecha_fin_proceso,
				@v_suma_cargos_aurus,
				@v_total_liquidado,
				@Usuario,
				@Mes,
				@Anio,
				@IdCicloFacturacion;
		END

		BEGIN
			SELECT @total_diferencias = count(clf.id_cuenta)
			FROM configurations.dbo.Control_Liquidacion_Facturacion clf
			WHERE clf.posee_diferencia = 1
		END

		COMMIT TRANSACTION;
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0)
			ROLLBACK TRANSACTION;

		RETURN 0;
	END CATCH

	-- Incrementar contador            
	SET @v_cta_i += 1;
END

RETURN @total_diferencias

GO
/****** Object:  StoredProcedure [dbo].[Facturacion_Main]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Facturacion_Main] (
	@v_id_log_facturacion INT = NULL,
	@v_id_ciclo_facturacion INT = NULL,
	@v_tipo CHAR(3) = NULL,
	@v_concepto CHAR(3) = NULL,
	@v_subconcepto CHAR(3) = NULL,
	@v_id_cuenta INT = NULL,
	@v_anio INT = NULL,
	@v_mes INT = NULL,
	@v_vuelta_facturacion VARCHAR(15) = NULL,
	@v_usuario_alta VARCHAR(20) = NULL,
	@v_version INT = NULL,
	@v_cuenta_aurus INT = NULL,
	@fecha_finProceso DATETIME = NULL
	)
AS
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

DECLARE @flag_calcular_compras INT;
DECLARE @flag_calcular_dev INT;
DECLARE @flag_actualizar INT;
DECLARE @CodRet_Carga INT;
DECLARE @CodRet_Proc INT

BEGIN TRANSACTION

BEGIN TRY
	TRUNCATE TABLE Configurations.dbo.Procesar_Facturacion_tmp;

	SET @CodRet_Carga = 0;
	SET @CodRet_Proc = 0;

	IF (
			@v_id_cuenta IS NULL
			OR @v_id_cuenta = 0
			OR (
				NOT EXISTS (
					SELECT 1
					FROM Configurations.dbo.Cuenta
					WHERE id_cuenta = @v_id_cuenta
					)
				)
			OR @fecha_finProceso IS NULL
			OR @v_id_log_facturacion IS NULL
			OR @v_id_log_facturacion = 0
			OR @v_id_ciclo_facturacion IS NULL
			OR @v_id_ciclo_facturacion = 0
			OR @v_tipo IS NULL
			OR @v_tipo = ''
			OR @v_concepto IS NULL
			OR @v_concepto = ''
			OR @v_subconcepto IS NULL
			OR @v_subconcepto = ''
			OR @v_anio IS NULL
			OR @v_anio = 0
			OR @v_mes IS NULL
			OR (
				@v_mes NOT BETWEEN 1
					AND 12
				)
			OR @v_vuelta_facturacion IS NULL
			OR @v_vuelta_facturacion = ''
			OR @v_usuario_alta IS NULL
			OR @v_usuario_alta = ''
			OR @v_version IS NULL
			OR @v_cuenta_aurus IS NULL
			OR @v_cuenta_aurus = ''
			)
	BEGIN
		SET @CodRet_Carga = 0;
	END
	ELSE
	BEGIN
		INSERT INTO [dbo].[Procesar_Facturacion_tmp] (
			[id],
			[LocationIdentification],
			[LiquidationTimeStamp],
			[LiquidationStatus],
			[BillingStatus],
			[BillingTimestamp],
			[CreateTimestamp],
			[FeeAmount],
			[TaxAmount],
			[OperationName]
			)
		SELECT tx.id,
			tx.LocationIdentification,
			tx.LiquidationTimestamp,
			tx.LiquidationStatus,
			tx.BillingStatus,
			tx.BillingTimestamp,
			tx.CreateTimestamp,
			tx.FeeAmount,
			tx.TaxAmount,
			tx.OperationName
		FROM Transactions.dbo.transactions tx
		WHERE LTRIM(RTRIM(tx.OperationName)) IN (
				'Compra_offline',
				'Compra_online'
				)
			AND tx.LiquidationTimestamp IS NOT NULL
			AND tx.LiquidationStatus = - 1
			AND tx.BillingStatus <> - 1
			AND tx.BillingTimestamp IS NULL
			AND tx.CreateTimestamp <= @fecha_finProceso
			AND tx.LocationIdentification = @v_id_cuenta
		
		UNION ALL
		
		SELECT tx.Id,
			tx.LocationIdentification,
			tx.LiquidationTimestamp,
			tx.LiquidationStatus,
			tx.BillingStatus,
			tx.BillingTimestamp,
			tx.CreateTimestamp,
			tx.FeeAmount,
			tx.TaxAmount,
			tx.OperationName
		FROM Transactions.dbo.transactions tx
		WHERE LTRIM(RTRIM(tx.OperationName)) IN ('Devolucion')
			AND tx.LiquidationTimestamp IS NOT NULL
			AND tx.LiquidationStatus = - 1
			AND tx.BillingStatus <> - 1
			AND tx.BillingTimestamp IS NULL
			AND tx.CreateTimestamp <= @fecha_finProceso
			AND tx.LocationIdentification = @v_id_cuenta;

		SET @CodRet_Carga = 1;
	END

	COMMIT TRANSACTION;
END TRY

BEGIN CATCH
	IF (@@TRANCOUNT > 0)
		ROLLBACK TRANSACTION;

	SET @CodRet_Carga = 0;

	RETURN @CodRet_Carga;
END CATCH

BEGIN TRY
	BEGIN TRANSACTION;

	IF (@CodRet_Carga = 1)
	BEGIN
		EXEC @flag_calcular_compras = Configurations.dbo.Facturacion_Calcular_Compras @v_id_log_facturacion,
			@v_id_ciclo_facturacion,
			@v_tipo,
			@v_concepto,
			@v_subconcepto,
			@v_id_cuenta,
			@v_anio,
			@v_mes,
			@v_vuelta_facturacion,
			@v_usuario_alta,
			@v_version,
			@v_cuenta_aurus,
			@fecha_finProceso;

		EXEC @flag_calcular_dev = Configurations.dbo.Facturacion_Calcular_Dev @v_id_log_facturacion,
			@v_id_ciclo_facturacion,
			@v_tipo,
			@v_concepto,
			@v_subconcepto,
			@v_id_cuenta,
			@v_anio,
			@v_mes,
			@v_vuelta_facturacion,
			@v_usuario_alta,
			@v_version,
			@v_cuenta_aurus,
			@fecha_finProceso;

		EXEC @flag_actualizar = Configurations.dbo.Facturacion_Actualizar_Procesados @fecha_finProceso,
			@v_id_cuenta;
	END

	IF (
			@flag_calcular_compras = 1
			AND @flag_calcular_dev = 1
			AND @flag_actualizar = 1
			)
	BEGIN
		SET @CodRet_Proc = 1;
	END
	ELSE
	BEGIN
		SET @CodRet_Proc = 0;
	END

	COMMIT TRANSACTION;
END TRY

BEGIN CATCH
	IF (@@TRANCOUNT > 0)
		ROLLBACK TRANSACTION;

	SET @CodRet_Proc = 0;

	RETURN @CodRet_Proc;
END CATCH

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

RETURN @CodRet_Proc;

GO
/****** Object:  StoredProcedure [dbo].[Finalizar_Log_Paso_Proceso]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Finalizar_Log_Paso_Proceso] (
	@id_log_paso INT = NULL,
	@archivo_salida VARCHAR(256) = NULL,
	@resultado_proceso BIT = NULL,
	@motivo_rechazo VARCHAR(100) = NULL,
	@registros_procesados INT = NULL,
	@importe_procesados DECIMAL(12,2) = NULL,
	@registros_aceptados INT = NULL,
	@importe_aceptados DECIMAL(12,2) = NULL,
	@registros_rechazados INT = NULL,
	@importe_rechazados DECIMAL(12,2) = NULL,
	@registros_salida INT = NULL,
	@importe_salida DECIMAL(12,2) = NULL,
	@usuario VARCHAR(20) = NULL
)            
AS

DECLARE @msg VARCHAR(255) = NULL;

SET NOCOUNT ON;

BEGIN TRANSACTION;

BEGIN TRY

	IF (@id_log_paso IS NULL)
		THROW 51000, 'Id Log Paso Nulo', 1;

	IF (NOT EXISTS (SELECT 1 FROM [dbo].[Log_Paso_Proceso] WHERE [id_log_paso] = @id_log_paso))
		THROW 51000, 'No existe Log Paso Proceso con el Id indicado', 1;

	IF (@resultado_proceso IS NULL)
		THROW 51000, 'Resultado Proceso Nulo', 1;

	IF (@usuario IS NULL)
		THROW 51000, 'Usuario Nulo', 1;

	UPDATE [dbo].[Log_Paso_Proceso]
	SET
		[fecha_fin_ejecucion] = GETDATE(),
		[archivo_salida] = @archivo_salida,
		[resultado_proceso] = @resultado_proceso,
		[motivo_rechazo] = @motivo_rechazo,
		[registros_procesados] = @registros_procesados,
		[importe_procesados] = @importe_procesados,
		[registros_aceptados] = @registros_aceptados,
		[importe_aceptados] = @importe_aceptados,
		[registros_rechazados] = @registros_rechazados,
		[importe_rechazados] = @importe_rechazados,
		[registros_salida] = @registros_salida,
		[importe_salida] = @importe_salida,
		[fecha_modificacion] = GETDATE(),
		[usuario_modificacion] = @usuario
	WHERE [id_log_paso] = @id_log_paso;

END TRY
BEGIN CATCH
	ROLLBACK TRANSACTION;
	SELECT @msg  = ERROR_MESSAGE();
	THROW  51000, @msg, 1;
END CATCH;

COMMIT TRANSACTION;

RETURN 1;

GO
/****** Object:  StoredProcedure [dbo].[Finalizar_Log_Proceso]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Finalizar_Log_Proceso] (
	@id_log_proceso INT = NULL,
	@registros_afectados INT = NULL,
	@usuario VARCHAR(20) = NULL
)            
AS

DECLARE @msg VARCHAR(255) = NULL;

SET NOCOUNT ON;

BEGIN TRANSACTION;

BEGIN TRY

	IF (@id_log_proceso IS NULL)
		THROW 51000, 'Id Log Proceso Nulo', 1;

	IF (NOT EXISTS (SELECT 1 FROM [dbo].[Log_Proceso] WHERE [id_log_proceso] = @id_log_proceso))
		THROW 51000, 'No existe Log Proceso con el Id indicado', 1;

	IF (@usuario IS NULL)
		THROW 51000, 'Usuario Nulo', 1;

	UPDATE [dbo].[Log_Proceso]
	SET
		[fecha_fin_ejecucion] = GETDATE(),
		[registros_afectados] = @registros_afectados,
		[fecha_modificacion] = GETDATE(),
		[usuario_modificacion] = @usuario
	WHERE [id_log_proceso] = @id_log_proceso;

END TRY
BEGIN CATCH
	ROLLBACK TRANSACTION;
	SELECT @msg  = ERROR_MESSAGE();
	THROW  51000, @msg, 1;
END CATCH;

COMMIT TRANSACTION;

RETURN 1;

GO
/****** Object:  StoredProcedure [dbo].[Iniciar_Log_Paso_Proceso]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Iniciar_Log_Paso_Proceso] (
	@id_log_proceso INT = NULL,
	@id_paso_proceso INT = NULL,
	@descripcion VARCHAR(25) = NULL,
	@archivo_entrada VARCHAR(256) = NULL,
	@usuario VARCHAR(20) = NULL
)            
AS

DECLARE @id_log_paso INT = NULL;
DECLARE @msg VARCHAR(255) = NULL;

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRANSACTION;

BEGIN TRY

	IF (@id_log_proceso IS NULL)
		THROW 51000, 'Id Log Proceso Nulo', 1;

	IF (NOT EXISTS (SELECT 1 FROM [dbo].[Log_Proceso] WHERE [id_log_proceso] = @id_log_proceso))
		THROW 51000, 'No existe Log Proceso con el Id indicado', 1;

	IF (@id_paso_proceso IS NULL)
		THROW 51000, 'Id Paso Proceso Nulo', 1;

	IF (NOT EXISTS (SELECT 1 FROM [dbo].[Paso_Proceso] WHERE [id_paso_proceso] = @id_paso_proceso))
		THROW 51000, 'No existe Paso Proceso con el Id indicado', 1;

	IF (NOT EXISTS (
		SELECT 1
		FROM [dbo].[Paso_Proceso]
		WHERE [paso] = @id_paso_proceso
		  AND [id_proceso] = (
			SELECT [id_proceso]
			FROM [dbo].[Log_Proceso]
			WHERE [id_log_proceso] = @id_log_proceso)
	))
		THROW 51000, 'El Id Proceso no corresponde al Id Paso', 1;

	IF (@usuario IS NULL)
		THROW 51000, 'Usuario Nulo', 1;

	SELECT
		@id_log_paso = ISNULL(MAX([id_log_paso]), 0) + 1
	FROM [dbo].[Log_Paso_Proceso];

	INSERT INTO [dbo].[Log_Paso_Proceso] (
		[id_log_paso],
		[id_log_proceso],
		[id_paso_proceso],
		[fecha_inicio_ejecucion],
		[descripcion],
		[archivo_entrada],
		[fecha_alta],
		[usuario_alta],
		[version]
	) VALUES (
		@id_log_paso,
		@id_log_proceso,
		@id_paso_proceso,
		GETDATE(),
		@descripcion,
		@archivo_entrada,
		GETDATE(),
		@usuario,
		0
	);

END TRY
BEGIN CATCH
	ROLLBACK TRANSACTION;
	SELECT @msg  = ERROR_MESSAGE(), @id_log_paso = NULL;
	THROW  51000, @msg, 1;
END CATCH;

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

RETURN @id_log_paso;

GO
/****** Object:  StoredProcedure [dbo].[Iniciar_Log_Proceso]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Iniciar_Log_Proceso] (
	@id_proceso INT = NULL,
	@fecha_desde_proceso DATETIME = NULL,
	@fecha_hasta_proceso DATETIME = NULL,
	@usuario VARCHAR(20) = NULL
)            
AS

DECLARE @id_log_proceso INT = NULL;
DECLARE @msg VARCHAR(255) = NULL;

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRANSACTION;

BEGIN TRY

	IF (@id_proceso IS NULL)
		THROW 51000, 'Id Proceso Nulo', 1;

	IF (NOT EXISTS (SELECT 1 FROM [dbo].[Proceso] WHERE [id_proceso] = @id_proceso))
		THROW 51000, 'No existe Proceso con el Id indicado', 1;

	IF (@usuario IS NULL)
		THROW 51000, 'Usuario Nulo', 1;

	SELECT
		@id_log_proceso = ISNULL(MAX([id_log_proceso]), 0) + 1
	FROM [dbo].[Log_Proceso];

	INSERT INTO [dbo].[Log_Proceso] (
		[id_log_proceso],
		[id_proceso],
		[fecha_inicio_ejecucion],
		[fecha_desde_proceso],
		[fecha_hasta_proceso],
		[fecha_alta],
		[usuario_alta],
		[version]
	) VALUES (
		@id_log_proceso,
		@id_proceso,
		GETDATE(),
		@fecha_desde_proceso,
		@fecha_hasta_proceso,
		GETDATE(),
		@usuario,
		0
	);

END TRY
BEGIN CATCH
	ROLLBACK TRANSACTION;
	SELECT @msg  = ERROR_MESSAGE(), @id_log_proceso = NULL;
	THROW  51000, @msg, 1;
END CATCH;

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

RETURN @id_log_proceso;

GO
/****** Object:  StoredProcedure [dbo].[Insertar_CUIT_LN]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
=============================================

Author:		 Mariela Romero
Create date: 09/09/2015
Description: Inserta CUITs en Lista negra validando longitud, formato y que no se encuentre en la tabla de LN
Origen:		 TPAGO-1145

Casos de prueba:

-- formato inválido
exec Insertar_CUIT_LN '987654gdg32100'
GO
-- longitud mayor
exec Insertar_CUIT_LN '98765432555100'	
GO
-- longitud menor
exec Insertar_CUIT_LN '987654300'	
GO
-- ok
exec Insertar_CUIT_LN '98765432102'	
GO
-- duplicado
exec Insertar_CUIT_LN '98765432102'	
GO

=============================================
*/
CREATE PROCEDURE [dbo].[Insertar_CUIT_LN] (
	@cuit varchar(20) 
)
AS
BEGIN

declare @mensaje varchar(100)

-- verifica no sea null
IF (@cuit is null)
 begin
	set @mensaje = 'ERROR: CUIT Nulo'
    ;THROW 51000, @mensaje, 1;
 end

-- verifica formato
BEGIN TRY
	 declare @big bigint
	 set @big = cast(@cuit as bigint)
END TRY
BEGIN CATCH
	set @mensaje = 'ERROR: CUIT ' + @CUIT + ' tiene formato inválido'
    ;THROW 51000, @mensaje, 1;
END CATCH

-- verifica longitud
IF (len(@cuit) <> 11)
 begin
	set @mensaje = 'ERROR: CUIT ' + @CUIT + ' tiene una longitud inválida'
    ;THROW 51000, @mensaje, 1;
 end

-- verifica unicidad
IF NOT EXISTS (
	SELECT * FROM Lista_Negra_CUIT where CUIT = @cuit and Usuario_Baja IS NULL
)
 begin
	INSERT INTO Lista_Negra_CUIT (CUIT, fecha_alta, usuario_alta)
	VALUES (@cuit, getdate(), 'Script')
	
	print 'OK: CUIT ' + @CUIT + ' Insertado'
 end
else 
 begin
	set @mensaje = 'ERROR: CUIT ' + @CUIT + ' ya se encuentra en la Lista Negra de CUITs'
    ;THROW 51000, @mensaje, 1;
 end

END


GO
/****** Object:  StoredProcedure [dbo].[Medios_Vencidos]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Medios_Vencidos] 
(
	@id_log_proceso INT = NULL,
	@usuario VARCHAR(20) = NULL,
	@contador INT OUTPUT
)        
    
AS

DECLARE @id_paso_proceso INT = 1;
DECLARE @msg VARCHAR(255) = NULL;
DECLARE @id_log_paso INT = NULL



SET NOCOUNT ON;

BEGIN TRY
BEGIN TRANSACTION;

-- Inicio Log paso proceso 

	EXEC  @id_log_paso = Configurations.dbo.Iniciar_Log_Paso_Proceso
	   @id_log_proceso
	  ,@id_paso_proceso
      ,NULL
      ,NULL
      ,@Usuario;

-- Inicio proceso 

BEGIN

		SELECT @contador = COUNT(*) FROM Configurations.dbo.medio_pago_cuenta 
		WHERE LEFT (fecha_vencimiento, 2) < DATEPART (MM, GETDATE())
		AND RIGHT (fecha_vencimiento, 4) = DATEPART (YYYY, GETDATE())
		AND id_estado_medio_pago <> 41

		UPDATE Configurations.dbo.medio_pago_cuenta
		SET id_estado_medio_pago = 41
		WHERE LEFT (fecha_vencimiento, 2) < DATEPART (MM, GETDATE())
		AND RIGHT (fecha_vencimiento, 4) = DATEPART (YYYY, GETDATE())
		AND id_estado_medio_pago <> 41

END


END TRY

BEGIN CATCH
    IF(@@TRANCOUNT > 0)
	ROLLBACK TRANSACTION;
	SELECT @msg  = ERROR_MESSAGE(), @id_log_paso = NULL;
	THROW  51000, @msg, 1;
END CATCH;

COMMIT TRANSACTION;

RETURN @id_log_paso;
GO
/****** Object:  StoredProcedure [dbo].[Obtener_cbu_pendientes]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
    
      
CREATE PROCEDURE [dbo].[Obtener_cbu_pendientes]      
AS      
SET NOCOUNT ON;      
      
DECLARE @dias INT;      
DECLARE @i INT = 1;      
DECLARE @count INT;      
DECLARE @cuit VARCHAR(11);      
DECLARE @entidad_solicitante VARCHAR(3);      
DECLARE @id_cuenta INT;      
DECLARE @fecha_inicio_pendiente DATE;      
DECLARE @fecha_vencimiento DATE;      
DECLARE @es_cuit_condicionado BIT;      
DECLARE @motivo VARCHAR(12);      
DECLARE @accion VARCHAR(10);      
DECLARE @entidad_registrada VARCHAR(3);      
DECLARE @msg VARCHAR(max);      
      
BEGIN      
 BEGIN TRY      
  -- Obtener plazo de días de espera para confirmar el nuevo CBU.      
  SELECT @dias = par.valor      
  FROM Configurations.dbo.Parametro par      
  WHERE codigo = 'dias_conf_CBU';      
      
  -- Limpiar tablas temporales      
  TRUNCATE TABLE Configurations.dbo.CBU_Pendientes_Tmp;      
      
  TRUNCATE TABLE Configurations.dbo.CUIT_A_Informar_Tmp;      
      
  BEGIN TRANSACTION;      
      
  -- Obtener CBUs pendientes de confirmar      
  INSERT INTO Configurations.dbo.CBU_Pendientes_Tmp (      
   cuit,      
   entidad_solicitante,      
   id_cuenta,      
   fecha_inicio_pendiente,      
   fecha_vencimiento,      
   entidad_registrada,      
   razon_social,      
   cbu,      
   id_banco,      
   tipo_acreditacion,      
   motivo,      
   accion      
   )      
  SELECT icb.cuit,      
   isnull(bco.codigo, bco2.codigo),      
   icb.id_cuenta,      
   cast(icb.fecha_inicio_pendiente AS DATE),      
   cast((icb.fecha_inicio_pendiente + @dias) AS DATE),      
   NULL,      
   ltrim(left(ltrim(rtrim(cta.denominacion1)) + ' ' + ltrim(rtrim(cta.denominacion2)), 50)),      
   icb.cbu_cuenta_banco,      
   isnull(bco.id_banco, bco2.id_banco),      
   tpo.codigo,      
   NULL,      
   (      
    CASE       
     WHEN est.codigo = 'CBU_FORZADO_EXC'      
      THEN 'CONFIRMAR'      
     ELSE NULL      
     END      
    )      
  FROM Configurations.dbo.Informacion_Bancaria_Cuenta icb      
  INNER JOIN Configurations.dbo.Cuenta cta      
   ON icb.id_cuenta = cta.id_cuenta      
  INNER JOIN Configurations.dbo.Tipo tpo      
   ON icb.id_tipo_cashout_solicitado = tpo.id_tipo      
    AND tpo.id_grupo_tipo = 18      
  INNER JOIN Configurations.dbo.Estado est      
   ON est.id_estado = icb.id_estado_informacion_bancaria      
  LEFT JOIN Configurations.dbo.Banco bco      
   ON ICB.fiid_banco = bco.codigo      
  LEFT JOIN Configurations.dbo.Banco bco2      
   ON ICB.fiidOrigenLink = bco2.codigo      
  WHERE icb.flag_vigente = 0      
   AND icb.fecha_baja IS NULL      
   AND est.codigo IN (      
    'CBU_PEND-HABILITAR',      
    'CBU_FORZADO_EXC'      
    )      
   AND est.id_grupo_estado = 11;      
      
  COMMIT TRANSACTION;      
      
  -- Para cada CBU pendiente en la tabla temporal      
  SELECT @count = count(*)      
  FROM Configurations.dbo.CBU_Pendientes_Tmp;      
      
  WHILE @i <= @count      
  BEGIN      
  set @entidad_registrada = null;  
   -- Obtener datos del CBU      
   SELECT @cuit = cpt.cuit,      
    @entidad_solicitante = cpt.entidad_solicitante,      
    @id_cuenta = cpt.id_cuenta,      
    @fecha_inicio_pendiente = cpt.fecha_inicio_pendiente,      
    @fecha_vencimiento = cpt.fecha_vencimiento,      
    @accion = cpt.accion      
   FROM Configurations.dbo.CBU_Pendientes_Tmp cpt      
   WHERE cpt.Id = @i;      
      
   -- Obtener entidad en la que el CUIT está registrado (si existe)      
   SELECT @entidad_registrada = isnull(bco.codigo, bco2.codigo)      
   FROM Configurations.dbo.Informacion_Bancaria_Cuenta icb      
   LEFT JOIN Configurations.dbo.Banco bco      
    ON ICB.fiid_banco = bco.codigo      
   LEFT JOIN Configurations.dbo.Banco bco2      
    ON ICB.fiidOrigenLink = bco2.codigo      
   WHERE icb.cuit = @cuit    
    AND icb.flag_vigente = 1;      
      
   -- Determinar el motivo      
   IF (@entidad_registrada IS NULL)      
    SET @motivo = 'ALTA';      
   ELSE      
    SET @motivo = 'MODIFICACION';      
      
   -- Si no se determinó acción a tomar      
   IF (@accion IS NULL)      
   BEGIN      
    -- Determinar si el CUIT está condicionado      
    SET @es_cuit_condicionado = (      
      SELECT CASE       
        WHEN c.cantidad_bancos > 0      
         THEN 1      
        ELSE 0      
        END      
      FROM (      
       SELECT count(*) AS cantidad_bancos      
       FROM Configurations.dbo.CUIT_Condicionado cco      
       INNER JOIN Configurations.dbo.Banco bco      
        ON cco.id_banco = bco.id_banco      
       WHERE cco.numero_CUIT = @cuit      
        AND cast(getdate() AS DATE) BETWEEN cco.fecha_inicio_vigencia      
         AND cco.fecha_fin_vigencia      
        AND cco.fecha_alta BETWEEN @fecha_inicio_pendiente      
         AND @fecha_vencimiento      
        AND cco.fecha_baja IS NULL      
        AND (      
         (      
          bco.codigo <> @entidad_solicitante      
          AND @motivo = 'ALTA'      
          )      
         OR (      
          bco.codigo = @entidad_registrada      
          AND @motivo = 'MODIFICACION'      
          )      
         )      
       ) c      
      );      
      
    -- Rechazar si no se venció el plazo de espera y el CUIT está condicionado      
    IF (      
      --cast(getdate() AS DATE) <= @fecha_vencimiento      
      --AND      
       @es_cuit_condicionado = 1      
      )      
     SET @accion = 'RECHAZAR';      
      
    -- Confirmar si se venció el plazo de espera y el CUIT no está condicionado      
    IF (      
      cast(getdate() AS DATE) > @fecha_vencimiento      
      AND @es_cuit_condicionado = 0      
      )      
     SET @accion = 'CONFIRMAR';      
      
    -- Informar si no se venció el plazo de espera y el CUIT no está condicionado      
    IF (      
      cast(getdate() AS DATE) <= @fecha_vencimiento      
      AND @es_cuit_condicionado = 0      
      )      
     SET @accion = 'INFORMAR';      
   END;      
      
   -- Si hay que informar      
   IF (@accion = 'INFORMAR')      
   BEGIN      
    -- Obtener los Bancos a los que hay que informar para un Alta      
    IF (@entidad_registrada IS NULL)      
    BEGIN      
     BEGIN TRANSACTION;      
      
     INSERT INTO Configurations.dbo.CUIT_A_Informar_Tmp      
     SELECT cpa.cuit,      
      @id_cuenta,      
      bco.codigo      
     FROM Configurations.dbo.Comercio_Prisma cpa      
     INNER JOIN Configurations.dbo.Banco bco      
      ON cpa.id_banco = bco.id_banco      
     WHERE cpa.cuit = @cuit      
      AND cpa.fecha_baja IS NULL      
      AND bco.codigo <> @entidad_solicitante;      
      
     COMMIT TRANSACTION;      
    END;      
      
    -- Obtener Banco al que hay que informar la Modificación      
    IF (@entidad_registrada IS NOT NULL)      
    BEGIN      
     BEGIN TRANSACTION;      
      
     INSERT INTO Configurations.dbo.CUIT_A_Informar_Tmp      
     SELECT cpa.cuit,      
      @id_cuenta,      
      bco.codigo      
     FROM Configurations.dbo.Comercio_Prisma cpa      
     INNER JOIN Configurations.dbo.Banco bco      
      ON cpa.id_banco = bco.id_banco      
     WHERE cpa.cuit = @cuit      
      AND cpa.fecha_baja IS NULL      
      AND bco.codigo = @entidad_registrada;      
      
     COMMIT TRANSACTION;      
    END;      
   END;      
      
   -- Actualizar temporal de CBUs pendientes      
   BEGIN TRANSACTION;      
      
   UPDATE Configurations.dbo.CBU_Pendientes_Tmp      
   SET entidad_registrada = @entidad_registrada,      
    motivo = @motivo,      
    accion = @accion      
   WHERE id = @i;      
      
   COMMIT TRANSACTION;      
      
   SET @i = @i + 1;      
  END;      
 END TRY      
      
 BEGIN CATCH      
  IF @@TRANCOUNT > 0      
   ROLLBACK TRANSACTION;      
      
  SELECT @msg = ERROR_MESSAGE();      
      
  THROW 51000,      
   @Msg,      
   1;      
 END CATCH;      
      
 RETURN 1;      
END;
GO
/****** Object:  StoredProcedure [dbo].[Obtener_Estado_Movimiento]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Obtener_Estado_Movimiento] (
                @id_medio_pago INT = NULL,
                @campo_mp_1 VARCHAR(10) = NULL,
                @valor_1 VARCHAR(15) = NULL,
                @campo_mp_2 VARCHAR(10) = NULL,
                @valor_2 VARCHAR(15) = NULL,
                @campo_mp_3 VARCHAR(10) = NULL,
                @valor_3 VARCHAR(15) = NULL
)            
AS

SET NOCOUNT ON;

DECLARE @estado_movimiento VARCHAR(1) = NULL;
DECLARE @msg VARCHAR(255) = NULL;

BEGIN TRANSACTION;

BEGIN TRY

                IF(@id_medio_pago IN (14, 30, 42))
                BEGIN

                   SELECT estado_movimiento FROM estado_movimiento_mp
                   WHERE id_medio_pago = @id_medio_pago
                   AND campo_mp_1 = @campo_mp_1
                   AND valor_1 = @valor_1
                END

                ELSE
                  SELECT estado_movimiento FROM estado_movimiento_mp
                   WHERE id_medio_pago = @id_medio_pago
                   AND campo_mp_1 = @campo_mp_1
                   AND valor_1 = @valor_1
                   AND campo_mp_2 = @campo_mp_2
                   AND valor_2 = @valor_2

END TRY

BEGIN CATCH
                ROLLBACK TRANSACTION;
                SELECT @msg  = ERROR_MESSAGE();
                THROW  51000, @msg, 1;
END CATCH;

COMMIT TRANSACTION;

RETURN @estado_movimiento;

GO
/****** Object:  StoredProcedure [dbo].[Saldos_Detallar_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[Saldos_Detallar_Cuenta] (@p_id_cuenta INT)
AS
-- Constantes de tipo de movimientos
DECLARE @tipo_transaccion CHAR(3) = 'VEN';
DECLARE @tipo_devolucion CHAR(3) = 'DEV';
DECLARE @tipo_cashout CHAR(3) = 'CSH';
DECLARE @tipo_ajuste CHAR(3) = 'AJU';
DECLARE @tipo_contracargo CHAR(3) = 'CCG';
-- Variables
DECLARE @i INT;
DECLARE @count INT;
DECLARE @detalles TABLE (id_detalle INT);
DECLARE @tipo CHAR(3);
DECLARE @temp TABLE (
	i INT PRIMARY KEY identity(1, 1),
	id_cuenta INT,
	id_log_proceso INT
	);
DECLARE @id_cuenta INT;
DECLARE @id_log_proceso INT;

BEGIN
	-- Verificar que se haya indicado una Cuenta
	IF (@p_id_cuenta IS NULL)
	BEGIN
		PRINT 'Debe indicarse un ID de Cuenta.';

		RETURN 0;
	END;

	BEGIN TRY
		BEGIN TRANSACTION;

		INSERT INTO Configurations.dbo.Detalle_Analisis_De_Saldo (
			fecha_de_analisis,
			tipo_movimiento,
			id_char,
			id_int,
			id_cuenta,
			importe_movimiento,
			fecha_movimiento,
			id_log_proceso,
			fecha_inicio_ejecucion,
			fecha_fin_ejecucion,
			id_log_movimiento,
			flag_impactar_en_saldo,
			impacto_en_saldo_ok
			)
		OUTPUT inserted.id_detalle
		INTO @detalles
		-- Ventas
		SELECT getdate() AS fecha_de_analisis,
			@tipo_transaccion AS tipo,
			transacciones.Id AS id_char,
			NULL AS id_int,
			transacciones.id_cuenta,
			transacciones.importe_movimiento,
			transacciones.LiquidationTimestamp AS fecha_movimiento,
			lpo.id_log_proceso,
			lpo.fecha_inicio_ejecucion,
			lpo.fecha_fin_ejecucion,
			NULL AS id_log_movimiento,
			1 AS flag_impactar_en_saldo,
			NULL AS impacto_en_saldo_ok
		FROM (
			SELECT trn.Id,
				trn.LocationIdentification AS id_cuenta,
				(trn.Amount - trn.FeeAmount - trn.TaxAmount) AS importe_movimiento,
				trn.LiquidationTimestamp
			FROM Transactions.dbo.transactions trn
			WHERE trn.ResultCode = - 1
				AND trn.OperationName <> 'devolucion'
				AND trn.LiquidationStatus = - 1
				AND trn.LocationIdentification = @p_id_cuenta
			) transacciones
		LEFT JOIN Configurations.dbo.Log_Proceso lpo
			ON transacciones.LiquidationTimestamp BETWEEN lpo.fecha_inicio_ejecucion
					AND lpo.fecha_fin_ejecucion
				AND lpo.id_proceso = 1
		
		UNION ALL
		
		-- Devoluciones
		SELECT getdate() AS fecha_de_analisis,
			@tipo_devolucion AS tipo,
			trn.Id AS id_char,
			NULL AS id_int,
			trn.LocationIdentification AS id_cuenta,
			((trn.Amount - isnull(trn.FeeAmount, 0) - isnull(trn.TaxAmount, 0)) * - 1) AS importe_movimiento,
			trn.CreateTimestamp AS fecha_movimiento,
			NULL AS id_log_proceso,
			NULL AS fecha_inicio_ejecucion,
			NULL AS fecha_fin_ejecucion,
			NULL AS id_log_movimiento,
			1 AS flag_impactar_en_saldo,
			NULL AS impacto_en_saldo_ok
		FROM Transactions.dbo.transactions trn
		WHERE trn.ResultCode = - 1
			AND trn.OperationName = 'devolucion'
			AND trn.LocationIdentification = @p_id_cuenta
		
		UNION ALL
		
		-- Cashout			
		SELECT getdate() AS fecha_de_analisis,
			@tipo_cashout AS tipo,
			NULL AS id_char,
			rdo.id_retiro_dinero AS id_int,
			rdo.id_cuenta,
			(rdo.monto * - 1) AS importe_movimiento,
			rdo.fecha_alta AS fecha_movimiento,
			NULL AS id_log_proceso,
			NULL AS fecha_inicio_ejecucion,
			NULL AS fecha_fin_ejecucion,
			NULL AS id_log_movimiento,
			1 AS flag_impactar_en_saldo,
			NULL AS impacto_en_saldo_ok
		FROM Configurations.dbo.Retiro_Dinero rdo
		WHERE rdo.estado_transaccion = 'TX_APROBADA'
			AND rdo.id_cuenta = @p_id_cuenta
		
		UNION ALL
		
		-- Ajustes
		SELECT getdate() AS fecha_de_analisis,
			@tipo_ajuste AS tipo,
			NULL AS id_char,
			aje.id_ajuste AS id_int,
			aje.id_cuenta,
			(
				CASE 
					WHEN cop.signo = '+'
						THEN aje.monto
					ELSE (aje.monto * - 1)
					END
				) AS importe_movimiento,
			aje.fecha_alta AS fecha_movimiento,
			NULL AS id_log_proceso,
			NULL AS fecha_inicio_ejecucion,
			NULL AS fecha_fin_ejecucion,
			NULL AS id_log_movimiento,
			1 AS flag_impactar_en_saldo,
			NULL AS impacto_en_saldo_ok
		FROM Configurations.dbo.Ajuste aje
		INNER JOIN Configurations.dbo.Codigo_Operacion cop
			ON cop.id_codigo_operacion = aje.id_codigo_operacion
		WHERE aje.id_cuenta = @p_id_cuenta
		
		UNION ALL
		
		-- Contracargos
		SELECT getdate() AS fecha_de_analisis,
			@tipo_contracargo AS tipo,
			dta.id_transaccion AS id_char,
			dta.id_disputa AS id_int,
			dta.id_cuenta,
			(trn.Amount * - 1) AS importe_movimiento,
			dta.fecha_resolucion_cuenta AS fecha_movimiento,
			lpo.id_log_proceso,
			lpo.fecha_inicio_ejecucion,
			lpo.fecha_fin_ejecucion,
			NULL AS id_log_movimiento,
			1 AS flag_impactar_en_saldo,
			NULL AS impacto_en_saldo_ok
		FROM Configurations.dbo.Disputa dta
		INNER JOIN Transactions.dbo.transactions trn
			ON dta.id_transaccion = trn.Id
		LEFT JOIN Configurations.dbo.Log_Proceso lpo
			ON dta.id_log_proceso = lpo.id_log_proceso
		WHERE dta.id_estado_resolucion_cuenta = 38
			AND dta.id_estado_resolucion_mp = 38
			AND trn.ChargebackStatus = 1
			AND dta.id_cuenta = @p_id_cuenta;

		COMMIT TRANSACTION;
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION;

		PRINT 'Error buscando movimientos.';

		throw;
	END CATCH

	-- Asignar Log de Movimientos de Cuenta Virtual
	BEGIN TRY
		BEGIN TRANSACTION;

		-- Para cada movimiento encontrado
		SELECT @i = min(id_detalle),
			@count = max(id_detalle)
		FROM @detalles;

		WHILE (@i <= @count)
		BEGIN
			-- Obtener el tipo de movimiento
			SELECT @tipo = das.tipo_movimiento
			FROM Configurations.dbo.Detalle_Analisis_De_Saldo das
			WHERE das.id_detalle = @i;

			-- Si es Transacción
			IF (@tipo = @tipo_transaccion)
				UPDATE Configurations.dbo.Detalle_Analisis_De_Saldo
				SET id_log_movimiento = (
						SELECT TOP 1 lmcv.id_log_movimiento
						FROM Configurations.dbo.Log_Movimiento_Cuenta_Virtual lmcv
						INNER JOIN Configurations.dbo.Detalle_Analisis_De_Saldo mov
							ON lmcv.id_log_proceso = mov.id_log_proceso
								AND lmcv.id_cuenta = mov.id_cuenta
								AND lmcv.monto_saldo_cuenta = mov.importe_movimiento
						INNER JOIN Configurations.dbo.Tipo t_mov
							ON lmcv.id_tipo_movimiento = t_mov.id_tipo
						INNER JOIN Configurations.dbo.Tipo t_ori
							ON lmcv.id_tipo_origen_movimiento = t_ori.id_tipo
						WHERE t_mov.codigo = 'MOV_CRED'
							AND t_ori.codigo IN (
								'ORIG_PROCESO',
								'ORIG_CORR_SALDO'
								)
							AND mov.id_detalle = @i
							AND NOT EXISTS (
								SELECT 1
								FROM Configurations.dbo.Detalle_Analisis_De_Saldo t
								WHERE t.id_log_movimiento = lmcv.id_log_movimiento
								)
						ORDER BY lmcv.fecha_alta
						)
				WHERE id_detalle = @i;

			-- Si es Devolución
			IF (@tipo = @tipo_devolucion)
				UPDATE Configurations.dbo.Detalle_Analisis_De_Saldo
				SET id_log_movimiento = (
						SELECT TOP 1 lmcv.id_log_movimiento
						FROM Configurations.dbo.Log_Movimiento_Cuenta_Virtual lmcv
						INNER JOIN Configurations.dbo.Detalle_Analisis_De_Saldo mov
							ON lmcv.id_cuenta = mov.id_cuenta
						INNER JOIN Configurations.dbo.Tipo t_mov
							ON lmcv.id_tipo_movimiento = t_mov.id_tipo
						INNER JOIN Configurations.dbo.Tipo t_ori
							ON lmcv.id_tipo_origen_movimiento = t_ori.id_tipo
						WHERE lmcv.id_log_proceso IS NULL
							AND t_mov.codigo = 'MOV_DEB'
							AND t_ori.codigo IN (
								'ORIG_DEV',
								'ORIG_CORR_SALDO'
								)
							AND lmcv.monto_saldo_cuenta = mov.importe_movimiento
							AND NOT EXISTS (
								SELECT 1
								FROM Configurations.dbo.Detalle_Analisis_De_Saldo t
								WHERE t.id_log_movimiento = lmcv.id_log_movimiento
								)
							AND mov.id_detalle = @i
						ORDER BY lmcv.fecha_alta
						)
				WHERE id_detalle = @i;

			-- Si es Cashout
			IF (@tipo = @tipo_cashout)
				UPDATE Configurations.dbo.Detalle_Analisis_De_Saldo
				SET id_log_movimiento = (
						SELECT TOP 1 lmcv.id_log_movimiento
						FROM Configurations.dbo.Log_Movimiento_Cuenta_Virtual lmcv
						INNER JOIN Configurations.dbo.Detalle_Analisis_De_Saldo mov
							ON lmcv.id_cuenta = mov.id_cuenta
						INNER JOIN Configurations.dbo.Tipo t_mov
							ON lmcv.id_tipo_movimiento = t_mov.id_tipo
						INNER JOIN Configurations.dbo.Tipo t_ori
							ON lmcv.id_tipo_origen_movimiento = t_ori.id_tipo
						WHERE lmcv.id_log_proceso IS NULL
							AND t_mov.codigo = 'MOV_DEB'
							AND t_ori.codigo IN (
								'ORIG_CASHOUT',
								'ORIG_CORR_SALDO'
								)
							AND lmcv.monto_saldo_cuenta = mov.importe_movimiento
							AND NOT EXISTS (
								SELECT 1
								FROM Configurations.dbo.Detalle_Analisis_De_Saldo t
								WHERE t.id_log_movimiento = lmcv.id_log_movimiento
								)
							AND mov.id_detalle = @i
						ORDER BY lmcv.fecha_alta
						)
				WHERE id_detalle = @i;

			-- Si es Ajuste
			IF (@tipo = @tipo_ajuste)
				UPDATE Configurations.dbo.Detalle_Analisis_De_Saldo
				SET id_log_movimiento = (
						SELECT TOP 1 lmcv.id_log_movimiento
						FROM Configurations.dbo.Log_Movimiento_Cuenta_Virtual lmcv
						INNER JOIN Configurations.dbo.Detalle_Analisis_De_Saldo mov
							ON lmcv.id_cuenta = mov.id_cuenta
						INNER JOIN Configurations.dbo.Tipo t_mov
							ON lmcv.id_tipo_movimiento = t_mov.id_tipo
						INNER JOIN Configurations.dbo.Tipo t_ori
							ON lmcv.id_tipo_origen_movimiento = t_ori.id_tipo
						WHERE lmcv.id_log_proceso IS NULL
							AND t_mov.codigo = (
								CASE 
									WHEN mov.importe_movimiento > 0
										THEN 'MOV_CRED'
									ELSE 'MOV_DEB'
									END
								)
							AND t_ori.codigo IN (
								'ORIG_PROCESO',
								'ORIG_CORR_SALDO'
								)
							AND lmcv.monto_saldo_cuenta = mov.importe_movimiento
							AND NOT EXISTS (
								SELECT 1
								FROM Configurations.dbo.Detalle_Analisis_De_Saldo t
								WHERE t.id_log_movimiento = lmcv.id_log_movimiento
								)
							AND mov.id_detalle = @i
						ORDER BY lmcv.fecha_alta
						)
				WHERE id_detalle = @i;

			-- Si es Contracargo
			IF (@tipo = @tipo_contracargo)
				UPDATE Configurations.dbo.Detalle_Analisis_De_Saldo
				SET id_log_movimiento = (
						SELECT TOP 1 lmcv.id_log_movimiento
						FROM Configurations.dbo.Log_Movimiento_Cuenta_Virtual lmcv
						INNER JOIN Configurations.dbo.Detalle_Analisis_De_Saldo mov
							ON lmcv.id_cuenta = mov.id_cuenta
						INNER JOIN Configurations.dbo.Tipo t_mov
							ON lmcv.id_tipo_movimiento = t_mov.id_tipo
						INNER JOIN Configurations.dbo.Tipo t_ori
							ON lmcv.id_tipo_origen_movimiento = t_ori.id_tipo
						WHERE lmcv.id_log_proceso IS NULL
							AND t_mov.codigo = 'MOV_DEB'
							AND t_ori.codigo IN (
								'ORIG_CTCGO',
								'ORIG_CORR_SALDO'
								)
							AND lmcv.monto_saldo_cuenta = mov.importe_movimiento
							AND NOT EXISTS (
								SELECT 1
								FROM Configurations.dbo.Detalle_Analisis_De_Saldo t
								WHERE t.id_log_movimiento = lmcv.id_log_movimiento
								)
							AND mov.id_detalle = @i
						ORDER BY lmcv.fecha_alta
						)
				WHERE id_detalle = @i;

			SET @i += 1;
		END;

		COMMIT TRANSACTION;
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION;

		PRINT 'Error buscando log de cuenta virtual.';

		throw;
	END CATCH

	-- Asignar Log de Movimientos de Cuenta Virtual para Ventas Liquidadas con el nuevo Liquidador
	BEGIN TRY
		BEGIN TRANSACTION;

		-- Para cada movimiento encontrado
		SELECT @i = min(id_detalle),
			@count = max(id_detalle)
		FROM @detalles;

		INSERT INTO @temp (
			id_cuenta,
			id_log_proceso
			)
		SELECT DISTINCT das.id_cuenta,
			das.id_log_proceso
		FROM Configurations.dbo.Detalle_Analisis_De_Saldo das
		WHERE das.id_log_movimiento IS NULL
			AND das.id_detalle BETWEEN @i
				AND @count;

		SET @i = 1;

		SELECT @count = count(1)
		FROM @temp;

		WHILE (@i <= @count)
		BEGIN
			SELECT @id_cuenta = id_cuenta,
				@id_log_proceso = id_log_proceso
			FROM @temp
			WHERE i = @i;

			UPDATE Configurations.dbo.Detalle_Analisis_De_Saldo
			SET id_log_movimiento = (
					SELECT TOP 1 mov.id_log_movimiento
					FROM (
						SELECT das.id_cuenta,
							das.id_log_proceso,
							sum(das.importe_movimiento) AS importe_movimiento
						FROM Configurations.dbo.Detalle_Analisis_De_Saldo das
						WHERE das.tipo_movimiento = 'VEN'
							AND das.id_log_movimiento IS NULL
							AND das.id_cuenta = @id_cuenta
							AND das.id_log_proceso = @id_log_proceso
						GROUP BY das.id_cuenta,
							das.id_log_proceso
						) ven
					INNER JOIN (
						SELECT lmcv.id_cuenta,
							lmcv.id_log_proceso,
							lmcv.monto_saldo_cuenta AS importe_movimiento,
							lmcv.id_log_movimiento
						FROM Log_Movimiento_Cuenta_Virtual lmcv
						INNER JOIN Configurations.dbo.Tipo t_mov
							ON lmcv.id_tipo_movimiento = t_mov.id_tipo
						INNER JOIN Configurations.dbo.Tipo t_ori
							ON lmcv.id_tipo_origen_movimiento = t_ori.id_tipo
						WHERE t_mov.codigo = 'MOV_CRED'
							AND t_ori.codigo IN (
								'ORIG_PROCESO',
								'ORIG_CORR_SALDO'
								)
							AND NOT EXISTS (
								SELECT 1
								FROM Configurations.dbo.Detalle_Analisis_De_Saldo das
								WHERE das.id_log_movimiento = lmcv.id_log_movimiento
								)
						) mov
						ON ven.id_cuenta = mov.id_cuenta
							AND ven.id_log_proceso = mov.id_log_proceso
							AND ven.importe_movimiento = mov.importe_movimiento
					)
			WHERE id_cuenta = @id_cuenta
				AND id_log_proceso = @id_log_proceso;

			SET @i += 1;
		END;

		COMMIT TRANSACTION;
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION;

		PRINT 'Error buscando log de cuenta virtual para ventas liquidadas con el nuevo liquidador.';

		throw;
	END CATCH

	-- No impactar en Saldos los movimientos ya impactados.
	BEGIN TRY
		BEGIN TRANSACTION;

		-- Para cada movimiento encontrado
		SELECT @i = min(id_detalle),
			@count = max(id_detalle)
		FROM @detalles;

		UPDATE Configurations.dbo.Detalle_Analisis_De_Saldo
		SET flag_impactar_en_saldo = 0
		WHERE id_log_movimiento IS NOT NULL
			AND id_detalle BETWEEN @i
				AND @count;

		COMMIT TRANSACTION;
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION;

		PRINT 'Error actualizando el flag de impacto en Saldo.';

		throw;
	END CATCH

	RETURN 1;
END

GO
/****** Object:  StoredProcedure [dbo].[Saldos_Generar_Analisis_Detallado]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[Saldos_Generar_Analisis_Detallado]
AS
DECLARE @i INT = 1;
DECLARE @count INT;
DECLARE @id_resumen INT;
DECLARE @id_cuenta INT;
DECLARE @ret_code INT;

BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		CREATE TABLE #Cuentas_A_Detallar (
			i INT PRIMARY KEY identity(1, 1),
			id_resumen INT,
			id_cuenta INT
			);

		INSERT INTO #Cuentas_A_Detallar (
			id_resumen,
			id_cuenta
			)
		SELECT id_resumen,
			id_cuenta
		FROM Configurations.dbo.Resumen_Analisis_De_Saldo
		WHERE flag_generar_detalle = 1
			AND (
				detalle_generado_ok <> 1
				OR detalle_generado_ok IS NULL
				);

		SELECT @count = count(1)
		FROM #Cuentas_A_Detallar;

		WHILE (@i <= @count)
		BEGIN
			SELECT @id_resumen = id_resumen,
				@id_cuenta = id_cuenta
			FROM #Cuentas_A_Detallar
			WHERE i = @i;

			EXEC @ret_code = Configurations.dbo.Saldos_Detallar_Cuenta @id_cuenta;

			UPDATE Configurations.dbo.Resumen_Analisis_De_Saldo
			SET detalle_generado_ok = (
					CASE 
						WHEN @ret_code = 1
							THEN 1
						ELSE 0
						END
					)
			WHERE id_resumen = @id_resumen;

			SET @i += 1;
		END;

		DROP TABLE #Cuentas_A_Detallar;
	END TRY

	BEGIN CATCH
		throw;
	END CATCH;

	RETURN 1;
END

GO
/****** Object:  StoredProcedure [dbo].[Saldos_Generar_Analisis_Resumido]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[Saldos_Generar_Analisis_Resumido] (@p_solo_cuentas_activas BIT = 0)
AS
DECLARE @i INT = 1;
DECLARE @count INT;
DECLARE @id_cuenta INT;

BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		CREATE TABLE #Cuentas_A_Resumir (
			i INT PRIMARY KEY identity(1, 1),
			id_cuenta INT
			);

		-- CORREGIR PARA RECUPERAR SOLO CUENTAS ACTIVAS --
		INSERT INTO #Cuentas_A_Resumir (id_cuenta)
		SELECT id_cuenta
		FROM Configurations.dbo.Cuenta cta
		INNER JOIN Configurations.dbo.Estado est
			ON cta.id_estado_cuenta = est.id_estado
		WHERE est.Codigo NOT IN (
				'CTA_CREADA',
				'CTA_CERRADA',
				'CTA_RECHAZADA',
				'CTA_VENCIDA'
				);

		SELECT @count = count(1)
		FROM #Cuentas_A_Resumir;

		WHILE (@i <= @count)
		BEGIN
			SELECT @id_cuenta = id_cuenta
			FROM #Cuentas_A_Resumir
			WHERE i = @i;

			EXEC Configurations.dbo.Saldos_Resumir_Cuenta @id_cuenta;

			SET @i += 1;
		END;

		DROP TABLE #Cuentas_A_Resumir;
	END TRY

	BEGIN CATCH
		throw;
	END CATCH;

	RETURN 1;
END

GO
/****** Object:  StoredProcedure [dbo].[Saldos_Impactar_Movimientos]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[Saldos_Impactar_Movimientos]
AS
-- Constantes de tipo de movimientos
DECLARE @tipo_transaccion CHAR(3) = 'VEN';
DECLARE @tipo_devolucion CHAR(3) = 'DEV';
DECLARE @tipo_cashout CHAR(3) = 'CSH';
DECLARE @tipo_ajuste CHAR(3) = 'AJU';
DECLARE @tipo_contracargo CHAR(3) = 'CCG';
-- Variables
DECLARE @id_tipo_origen_movimiento INT;
DECLARE @id_tipo_mov_debito INT;
DECLARE @id_tipo_mov_credito INT;
DECLARE @i INT = 1;
DECLARE @count INT;
DECLARE @id_detalle INT;
DECLARE @id_cuenta INT;
DECLARE @tipo_movimiento CHAR(3);
DECLARE @importe_movimiento DECIMAL(12, 2);
DECLARE @id_log_proceso INT;
DECLARE @monto_disponible DECIMAL(12, 2);
DECLARE @validacion_disponible DECIMAL(12, 2);
DECLARE @monto_saldo_en_cuenta DECIMAL(12, 2);
DECLARE @validacion_saldo_en_cuenta DECIMAL(12, 2);
DECLARE @monto_saldo_en_revision DECIMAL(12, 2);
DECLARE @validacion_saldo_en_revision DECIMAL(12, 2);
DECLARE @usuario_alta VARCHAR(20) = 'SP_ANALISIS_SALDOS';
DECLARE @id_tipo_movimiento INT;
DECLARE @flag_ok INT;

BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRANSACTION;

		SELECT @id_tipo_origen_movimiento = id_tipo
		FROM Configurations.dbo.Tipo
		WHERE codigo = 'ORIG_CORR_SALDO';

		SELECT @id_tipo_mov_debito = id_tipo
		FROM Configurations.dbo.Tipo
		WHERE codigo = 'MOV_DEB';

		SELECT @id_tipo_mov_credito = id_tipo
		FROM Configurations.dbo.Tipo
		WHERE codigo = 'MOV_CRED';

		CREATE TABLE #Movimientos (
			id_movimiento INT PRIMARY KEY identity(1, 1),
			id_detalle INT
			);

		INSERT INTO #Movimientos (id_detalle)
		SELECT das.id_detalle
		FROM Configurations.dbo.Detalle_Analisis_De_Saldo das
		WHERE das.flag_impactar_en_saldo = 1
			AND (
				das.impacto_en_saldo_ok <> 1
				OR das.impacto_en_saldo_ok IS NULL
				);

		SELECT @count = count(1)
		FROM #Movimientos;

		WHILE (@i <= @count)
		BEGIN
			SELECT @id_detalle = das.id_detalle,
				@id_cuenta = das.id_cuenta,
				@tipo_movimiento = das.tipo_movimiento,
				@importe_movimiento = das.importe_movimiento,
				@id_log_proceso = das.id_log_proceso
			FROM Configurations.dbo.Detalle_Analisis_De_Saldo das
			INNER JOIN #Movimientos mov
				ON das.id_detalle = mov.id_detalle
			WHERE mov.id_movimiento = @i;

			IF (@tipo_movimiento = @tipo_transaccion)
			BEGIN
				SET @monto_disponible = NULL;
				SET @validacion_disponible = NULL;
				SET @monto_saldo_en_cuenta = @importe_movimiento;
				SET @validacion_saldo_en_cuenta = NULL;
				SET @monto_saldo_en_revision = NULL;
				SET @validacion_saldo_en_revision = NULL;
				SET @id_tipo_movimiento = @id_tipo_mov_credito;
			END;

			IF (@tipo_movimiento = @tipo_devolucion)
			BEGIN
				SET @monto_disponible = @importe_movimiento;
				SET @validacion_disponible = NULL;
				SET @monto_saldo_en_cuenta = @importe_movimiento;
				SET @validacion_saldo_en_cuenta = NULL;
				SET @monto_saldo_en_revision = NULL;
				SET @validacion_saldo_en_revision = NULL;
				SET @id_tipo_movimiento = @id_tipo_mov_debito;
			END;

			IF (@tipo_movimiento = @tipo_cashout)
			BEGIN
				SET @monto_disponible = @importe_movimiento;
				SET @validacion_disponible = NULL;
				SET @monto_saldo_en_cuenta = @importe_movimiento;
				SET @validacion_saldo_en_cuenta = NULL;
				SET @monto_saldo_en_revision = NULL;
				SET @validacion_saldo_en_revision = NULL;
				SET @id_tipo_movimiento = @id_tipo_mov_debito;
			END;

			BEGIN TRY
				EXEC @flag_ok = Configurations.dbo.Actualizar_Cuenta_Virtual @monto_disponible,
					@validacion_disponible,
					@monto_saldo_en_cuenta,
					@validacion_saldo_en_cuenta,
					@monto_saldo_en_revision,
					@validacion_saldo_en_revision,
					@id_cuenta,
					@usuario_alta,
					@id_tipo_movimiento,
					@id_tipo_origen_movimiento,
					@id_log_proceso;
			END TRY

			BEGIN CATCH
				SET @flag_ok = 0;

				SELECT 'Error al intentar impactar Saldo en la Cuenta' = @id_cuenta;
			END CATCH;

			UPDATE Configurations.dbo.Detalle_Analisis_De_Saldo
			SET impacto_en_saldo_ok = (
					CASE 
						WHEN @flag_ok = 1
							THEN 1
						ELSE 0
						END
					)
			WHERE id_detalle = @id_detalle;

			SET @i += 1;
		END;

		DROP TABLE #Movimientos;

		COMMIT TRANSACTION;
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0)
			ROLLBACK TRANSACTION;

		throw;
	END CATCH;

	RETURN 1;
END

GO
/****** Object:  StoredProcedure [dbo].[Saldos_Resumir_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Create PROCEDURE [dbo].[Saldos_Resumir_Cuenta] (@p_id_cuenta INT = NULL)
AS
DECLARE @inserted TABLE (id_resumen INT);

BEGIN
	SET NOCOUNT ON;

	IF (@p_id_cuenta IS NULL)
		RETURN 0;

	BEGIN TRY
		BEGIN TRANSACTION;

		INSERT INTO Configurations.dbo.Resumen_Analisis_De_Saldo (
			id_cuenta,
			fecha_de_analisis,
			cantidad_ventas,
			importe_ventas,
			cantidad_devoluciones,
			importe_devoluciones,
			cantidad_cashout,
			importe_cashout,
			cantidad_ajustes,
			importe_ajustes,
			cantidad_contracargos,
			importe_contracargos,
			cantidad_total_movimientos,
			importe_total_movimientos,
			saldo_en_cuenta,
			diferencia_de_saldo,
			log_movimientos_cuenta_ok,
			flag_generar_detalle,
			detalle_generado_ok
			)
		OUTPUT inserted.id_resumen
		INTO @inserted
		SELECT mov.id_cuenta,
			getdate(),
			mov.cantidad_ventas,
			mov.importe_ventas,
			mov.cantidad_devoluciones,
			mov.importe_devoluciones,
			mov.cantidad_cashout,
			mov.importe_cashout,
			mov.cantidad_ajustes,
			mov.importe_ajustes,
			mov.cantidad_contracargos,
			mov.importe_contracargos,
			(mov.cantidad_ventas + mov.cantidad_devoluciones + mov.cantidad_cashout + mov.cantidad_ajustes + mov.cantidad_contracargos),
			(mov.importe_ventas + mov.importe_devoluciones + mov.importe_cashout + mov.importe_ajustes + mov.importe_contracargos),
			mov.saldo_en_cuenta,
			(mov.importe_ventas + mov.importe_devoluciones + mov.importe_cashout + mov.importe_ajustes + mov.importe_contracargos) - mov.saldo_en_cuenta,
			0,
			0,
			NULL
		FROM (
			SELECT cta.id_cuenta,
				isnull(vta.cantidad_ventas, 0) AS cantidad_ventas,
				isnull(vta.importe_ventas, 0) AS importe_ventas,
				isnull(dev.cantidad_devoluciones, 0) AS cantidad_devoluciones,
				isnull(dev.importe_devoluciones, 0) AS importe_devoluciones,
				isnull(cas.cantidad_cashout, 0) AS cantidad_cashout,
				isnull(cas.importe_cashout, 0) AS importe_cashout,
				isnull(aju.cantidad_ajustes, 0) AS cantidad_ajustes,
				isnull(aju.importe_ajustes, 0) AS importe_ajustes,
				isnull(cco.cantidad_contracargos, 0) AS cantidad_contracargos,
				isnull(cco.importe_contracargos, 0) AS importe_contracargos,
				isnull(sec.saldo_en_cuenta, 0) AS saldo_en_cuenta
			FROM Configurations.dbo.Cuenta cta
			-- ventas
			LEFT JOIN (
				SELECT trn.LocationIdentification AS id_cuenta,
					count(1) AS cantidad_ventas,
					sum(trn.Amount - trn.FeeAmount - trn.TaxAmount) AS importe_ventas
				FROM Transactions.dbo.transactions trn
				WHERE trn.ResultCode = - 1
					AND trn.LiquidationStatus = - 1
					AND trn.OperationName <> 'devolucion'
					AND trn.LocationIdentification = @p_id_cuenta
				GROUP BY trn.LocationIdentification
				) vta
				ON cta.id_cuenta = vta.id_cuenta
			-- devoluciones
			LEFT JOIN (
				SELECT trn.LocationIdentification AS id_cuenta,
					count(1) AS cantidad_devoluciones,
					sum(trn.Amount - isnull(trn.FeeAmount, 0) - isnull(trn.TaxAmount, 0)) * - 1 AS importe_devoluciones
				FROM Transactions.dbo.transactions trn
				WHERE trn.ResultCode = - 1
					AND trn.OperationName = 'devolucion'
					AND trn.LocationIdentification = @p_id_cuenta
				GROUP BY trn.LocationIdentification
				) dev
				ON cta.id_cuenta = dev.id_cuenta
			-- cashout
			LEFT JOIN (
				SELECT rdo.id_cuenta,
					count(1) AS cantidad_cashout,
					sum(rdo.monto) * - 1 AS importe_cashout
				FROM Configurations.dbo.Retiro_Dinero rdo
				WHERE rdo.estado_transaccion = 'TX_APROBADA'
					AND rdo.id_cuenta = @p_id_cuenta
				GROUP BY rdo.id_cuenta
				) cas
				ON cta.id_cuenta = cas.id_cuenta
			-- ajustes
			LEFT JOIN (
				SELECT aje.id_cuenta,
					count(1) AS cantidad_ajustes,
					sum(CASE 
							WHEN cop.signo = '+'
								THEN aje.monto
							ELSE (aje.monto * - 1)
							END) AS importe_ajustes
				FROM Configurations.dbo.Ajuste aje
				INNER JOIN Configurations.dbo.Codigo_Operacion cop
					ON cop.id_codigo_operacion = aje.id_codigo_operacion
				WHERE aje.id_cuenta = @p_id_cuenta
				GROUP BY aje.id_cuenta
				) aju
				ON cta.id_cuenta = aju.id_cuenta
			-- contracargos
			LEFT JOIN (
				SELECT dta.id_cuenta,
					count(1) AS cantidad_contracargos,
					sum(trn.Amount * - 1) AS importe_contracargos
				FROM Configurations.dbo.Disputa dta
				INNER JOIN Transactions.dbo.transactions trn
					ON dta.id_transaccion = trn.Id
				WHERE dta.id_estado_resolucion_cuenta = 38
					AND dta.id_estado_resolucion_mp = 38
					AND trn.ChargebackStatus = 1
					AND dta.id_cuenta = @p_id_cuenta
				GROUP BY dta.id_cuenta
				) cco
				ON cta.id_cuenta = cco.id_cuenta
			-- saldo en cuenta
			LEFT JOIN (
				SELECT cvt.id_cuenta,
					cvt.saldo_en_cuenta
				FROM Configurations.dbo.Cuenta_Virtual cvt
				WHERE cvt.id_cuenta = @p_id_cuenta
				) sec
				ON cta.id_cuenta = sec.id_cuenta
			WHERE cta.id_cuenta = @p_id_cuenta
			) mov;

		UPDATE Configurations.dbo.Resumen_Analisis_De_Saldo
		SET log_movimientos_cuenta_ok = (
				SELECT CASE 
						WHEN l.errores = 0
							THEN 1
						ELSE 0
						END
				FROM (
					SELECT count(1) AS errores
					FROM (
						SELECT lmcv.id_log_movimiento,
							lag(lmcv.disponible_actual, 1, 0) OVER (
								ORDER BY lmcv.fecha_alta
								) AS disponible_registro_anterior,
							lmcv.disponible_anterior,
							lmcv.disponible_actual,
							lag(lmcv.saldo_cuenta_actual, 1, 0) OVER (
								ORDER BY lmcv.fecha_alta
								) AS saldo_cuenta_registro_anterior,
							lmcv.saldo_cuenta_anterior,
							lmcv.saldo_cuenta_actual,
							lag(lmcv.saldo_revision_actual, 1, 0) OVER (
								ORDER BY lmcv.fecha_alta
								) AS saldo_revision_registro_anterior,
							lmcv.saldo_revision_anterior,
							lmcv.saldo_revision_actual
						FROM dbo.Log_Movimiento_Cuenta_Virtual lmcv
						WHERE lmcv.id_cuenta = @p_id_cuenta
						) logs
					WHERE logs.disponible_registro_anterior <> logs.disponible_anterior
						OR logs.saldo_cuenta_registro_anterior <> logs.saldo_cuenta_anterior
						OR logs.saldo_revision_registro_anterior <> logs.saldo_revision_anterior
					) l
				)
		WHERE id_resumen = (
				SELECT TOP 1 id_resumen
				FROM @inserted
				);

		UPDATE Configurations.dbo.Resumen_Analisis_De_Saldo
		SET flag_generar_detalle = (
				SELECT CASE 
						WHEN ras.diferencia_de_saldo <> 0
							OR ras.log_movimientos_cuenta_ok = 0
							THEN 1
						ELSE 0
						END
				FROM Configurations.dbo.Resumen_Analisis_De_Saldo ras
				WHERE ras.id_resumen = (
						SELECT TOP 1 id_resumen
						FROM @inserted
						)
				)
		WHERE id_resumen = (
				SELECT TOP 1 id_resumen
				FROM @inserted
				);

		COMMIT TRANSACTION;
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION;

		throw;
	END CATCH;

	RETURN 1;
END

GO
/****** Object:  StoredProcedure [dbo].[sp_GenerarCredencialesPruebas]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_GenerarCredencialesPruebas] ( 
		@idCuenta int,
		@idTipoCuenta int,
		@mail varchar(50),
		@clave varchar(50),
		@idPreguntaSeguridad int,
		@respuestaPreguntaSeguridad varchar(50),
		@apiKeyPruebas varchar(64)
)

AS 

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @idCuentaTmp int
	DECLARE @idTipoIdentificacion int
	DECLARE @numeroIdentificacion varchar(20)
	DECLARE @numeroCuit varchar(11)
	DECLARE @idDomicilioFacturacion int
	DECLARE @idParametroCuenta int


BEGIN TRY

	-- Validamos todos los parametros de entrada, menos idCuenta que puede ser NULL.

	IF (@idTipoCuenta IS NULL)
		THROW 51000, 'El parametro idTipoCuenta es NULL.', 1;

	IF (@mail IS NULL)
		THROW 51000, 'El parametro mail es NULL.', 1;

	IF (@clave IS NULL)
		THROW 51000, 'El parametro clave es NULL.', 1;

	IF (@idPreguntaSeguridad IS NULL)
		THROW 51000, 'El parametro idPreguntaSeguridad es NULL.', 1;

	IF (@respuestaPreguntaSeguridad IS NULL)
		THROW 51000, 'El parametro respuestaPreguntaSeguridad es NULL.', 1;

	IF (@apiKeyPruebas IS NULL)
		THROW 51000, 'El parametro apiKeyPruebas es NULL.', 1;

	IF (@idTipoCuenta NOT IN (27,28,29))
		THROW 51000, 'El parametro idTipoCuenta no es valido.', 1;

	
	-- Inicializamos algunas variables segun idTipoCuenta.

	IF (@idTipoCuenta = 27)
		BEGIN
			SET @idTipoIdentificacion = 21
			SET @numeroIdentificacion = '12345678'
			SET @numeroCuit = NULL
		END
	ELSE IF (@idTipoCuenta = 28)
		BEGIN
			SET @idTipoIdentificacion = 21
			SET @numeroIdentificacion = '12345678'
			SET @numeroCuit = '20123456784'
		END
	ELSE IF (@idTipoCuenta = 29)
		BEGIN
			SET @idTipoIdentificacion = NULL
			SET @numeroIdentificacion = NULL
			SET @numeroCuit = '30123456789'
		END
	

	
	BEGIN TRANSACTION

	-- Verificamos si existe el mail buscando el id_cuenta asociado

	SELECT @idCuentaTmp = id_cuenta FROM Usuario_Cuenta WHERE eMail = @mail
			
	
	-- Si existe la cuenta para el mail que viene por parametros, entonces
	-- actualizamos la columna "api_key" de la tabla "Parametro_Cuenta"

	IF (@idCuentaTmp IS NOT NULL) 
		BEGIN
			UPDATE Parametro_Cuenta
				SET api_key = @apiKeyPruebas, 
					api_key_pruebas = @apiKeyPruebas,
					fecha_modificacion = GETDATE(), 
					usuario_modificacion = 'API_Key_SP'
			WHERE id_cuenta = @idCuentaTmp
		END

	
	-- Si no existe la cuenta para el mail que viene por parametros, entonces 
	-- generamos toda la estructura de datos.
	
	IF (@idCuentaTmp IS NULL) 
		BEGIN

			-- Realizamos inserciones en Cuenta, Contacto_Cuenta, Cuenta_Virtual, Domicilio_Cuenta, 
			-- Situacion_Fiscal_Cuenta, Usuario_Cuenta, Parametro_Cuenta

			INSERT INTO Cuenta  ( id_tipo_cuenta,    denominacion1,    denominacion2, id_tipo_identificacion, numero_identificacion, numero_CUIT, sexo, id_nacionalidad, fecha_nacimiento, id_canal, id_estado_cuenta, id_version_tyc, flag_envio_novedades, fecha_alta, usuario_alta, fecha_modificacion, usuario_modificacion, fecha_baja, usuario_baja, version, telefono_movil, telefono_fijo, flag_cambio_pendiente, flag_informado_a_facturacion, id_operador_celular, id_banco_adhesion, flag_factor_validacion)
						VALUES  (  @idTipoCuenta, 'Prueba Empresa', 'Prueba Empresa',  @idTipoIdentificacion, @numeroIdentificacion, @numeroCuit, NULL,            NULL,             NULL,        1,                4,              1,                    1,  GETDATE(), 'API_Key_SP',               NULL,                 NULL,       NULL,         NULL,       0,   '1134567890',  '1144891088',                     0,                            0,                   3,              NULL,                   NULL)

			SET @idCuentaTmp = SCOPE_IDENTITY() -- Obtengo el nuevo id de la cuenta que acabo de insertar.

			INSERT INTO Contacto_Cuenta (    id_cuenta, nombre_contacto, apellido_contacto, telefono_movil, id_tipo_identificacion, numero_identificacion, fecha_alta, usuario_alta, fecha_modificacion, usuario_modificacion, fecha_baja, usuario_baja, version, id_operador_celular)
								VALUES  (@idCuentaTmp,          'Juan',           'Perez',   '1145678901',                     21,            '23456789',  GETDATE(), 'API_Key_SP',               NULL,                 NULL,       NULL,         NULL,       0,                   3)

			INSERT INTO Cuenta_Virtual (    id_cuenta, saldo_en_cuenta, saldo_en_revision, disponible, id_proceso_modificacion, id_tipo_cashout, fecha_alta, usuario_alta, fecha_modificacion, usuario_modificacion, fecha_baja, usuario_baja, version)
								VALUES ( @idCuentaTmp,            0.00,              0.00,       0.00,                    NULL,              62,  GETDATE(), 'API_Key_SP',               NULL,                 NULL,       NULL,         NULL,       0)

			INSERT INTO Domicilio_Cuenta ( id_tipo_domicilio,    id_cuenta,   calle, numero, piso, departamento, id_localidad, id_provincia, codigo_postal, fecha_alta, usuario_alta, fecha_modificacion, usuario_modificacion, fecha_baja, usuario_baja, version, flag_vigente)
								 VALUES  (                30, @idCuentaTmp, 'Calle', '1234', NULL,         NULL,           11,            1,        '1010',  GETDATE(), 'API_Key_SP',               NULL,                 NULL,       NULL,         NULL,       0,            0)

			INSERT INTO Domicilio_Cuenta ( id_tipo_domicilio,    id_cuenta,   calle, numero, piso, departamento, id_localidad, id_provincia, codigo_postal, fecha_alta, usuario_alta, fecha_modificacion, usuario_modificacion, fecha_baja, usuario_baja, version, flag_vigente)
								 VALUES  (                31, @idCuentaTmp, 'Calle', '1234', NULL,         NULL,           11,            1,        '1010',  GETDATE(), 'API_Key_SP',               NULL,                 NULL,       NULL,         NULL,       0,            1)

			SET @idDomicilioFacturacion = SCOPE_IDENTITY()

			IF (@idTipoCuenta = 27)
				BEGIN
					INSERT INTO Situacion_Fiscal_Cuenta (    id_cuenta, numero_CUIT,        razon_social, id_domicilio_facturacion, id_tipo_condicion_IVA, porcentaje_exclusion_iva, fecha_hasta_exclusion_IVA, id_tipo_condicion_IIBB, porcentaje_exclusion_IIBB, fecha_hasta_exclusion_IIBB, id_estado_documentacion, id_motivo_estado, flag_vigente, fecha_inicio_vigencia, fecha_fin_vigencia, fecha_alta, usuario_alta, fecha_modificacion, usuario_modificacion, fecha_baja, usuario_baja, fecha_validacion, usuario_validador, version, flag_validacion_excepcion, nro_inscripcion_IIBB)
												 VALUES ( @idCuentaTmp, @numeroCuit, 'Prueba Particular',  @idDomicilioFacturacion,                     1,                     NULL,                      NULL,                   NULL,                      NULL,                       NULL,                      20,             NULL,            1,                  NULL,               NULL,  GETDATE(), 'API_Key_SP',               NULL,                 NULL,       NULL,         NULL,             NULL,              NULL,       0,                         0,                 NULL)
				END

			IF (@idTipoCuenta = 28)
				BEGIN
					INSERT INTO Situacion_Fiscal_Cuenta (    id_cuenta, numero_CUIT,  razon_social, id_domicilio_facturacion, id_tipo_condicion_IVA, porcentaje_exclusion_iva, fecha_hasta_exclusion_IVA, id_tipo_condicion_IIBB, porcentaje_exclusion_IIBB, fecha_hasta_exclusion_IIBB, id_estado_documentacion, id_motivo_estado, flag_vigente, fecha_inicio_vigencia, fecha_fin_vigencia, fecha_alta, usuario_alta, fecha_modificacion, usuario_modificacion, fecha_baja, usuario_baja, fecha_validacion, usuario_validador, version, flag_validacion_excepcion, nro_inscripcion_IIBB)
												 VALUES ( @idCuentaTmp, @numeroCuit, 'Prueba Prof',  @idDomicilioFacturacion,                     1,                     NULL,                      NULL,                   NULL,                      NULL,                       NULL,                      20,             NULL,            0,                  NULL,               NULL,  GETDATE(), 'API_Key_SP',               NULL,                 NULL,       NULL,         NULL,             NULL,              NULL,       0,                         0,                 NULL)

					INSERT INTO Situacion_Fiscal_Cuenta (    id_cuenta, numero_CUIT,  razon_social, id_domicilio_facturacion, id_tipo_condicion_IVA, porcentaje_exclusion_iva, fecha_hasta_exclusion_IVA, id_tipo_condicion_IIBB, porcentaje_exclusion_IIBB, fecha_hasta_exclusion_IIBB, id_estado_documentacion, id_motivo_estado, flag_vigente, fecha_inicio_vigencia, fecha_fin_vigencia, fecha_alta, usuario_alta, fecha_modificacion, usuario_modificacion, fecha_baja, usuario_baja, fecha_validacion, usuario_validador, version, flag_validacion_excepcion, nro_inscripcion_IIBB)
												 VALUES ( @idCuentaTmp, @numeroCuit, 'Prueba Prof',  @idDomicilioFacturacion,                     4,                     NULL,                      NULL,                     10,                      NULL,                       NULL,                      17,             NULL,            1,             GETDATE(),               NULL,  GETDATE(), 'API_Key_SP',               NULL,                 NULL,       NULL,         NULL,        GETDATE(),      'API_Key_SP',       0,                         1,                 NULL)
				END

			IF (@idTipoCuenta = 29)
				BEGIN
					INSERT INTO Situacion_Fiscal_Cuenta (    id_cuenta,   numero_CUIT,     razon_social, id_domicilio_facturacion, id_tipo_condicion_IVA, porcentaje_exclusion_iva, fecha_hasta_exclusion_IVA, id_tipo_condicion_IIBB, porcentaje_exclusion_IIBB, fecha_hasta_exclusion_IIBB, id_estado_documentacion, id_motivo_estado, flag_vigente, fecha_inicio_vigencia, fecha_fin_vigencia, fecha_alta, usuario_alta, fecha_modificacion, usuario_modificacion, fecha_baja, usuario_baja, fecha_validacion, usuario_validador, version, flag_validacion_excepcion, nro_inscripcion_IIBB)
												 VALUES ( @idCuentaTmp,   @numeroCuit, 'Prueba Empresa',  @idDomicilioFacturacion,                     4,                     NULL,                      NULL,                     10,                      NULL,                       NULL,                      17,             NULL,            1,             GETDATE(),               NULL,  GETDATE(), 'API_Key_SP',               NULL,                 NULL,       NULL,         NULL,        GETDATE(),      'API_Key_SP',       0,                         1,                 NULL)
				END


			INSERT INTO Usuario_Cuenta (    id_cuenta, eMail, mail_confirmado, id_pregunta_seguridad, respuesta_pregunta_seguridad, password, ultimas_password, password_bloqueada, intentos_login, ultima_modificacion_password, fecha_ultimo_login, ip_ultimo_login, fecha_alta, usuario_alta, fecha_modificacion, usuario_modificacion, fecha_baja, usuario_baja, version, id_estado_mail,perfil)
								VALUES ( @idCuentaTmp, @mail,               1,  @idPreguntaSeguridad,  @respuestaPreguntaSeguridad,   @clave,             NULL,                  0,              0,                         NULL,               NULL,            NULL,  GETDATE(), 'API_Key_SP',               NULL,                 NULL,       NULL,         NULL,       0,           NULL,  NULL)


			-- Tenemos que generar un registro en Parametro_Cuenta para almacenar la APIKey.
			-- Primero verificamos si existe el registro insertado en Parametro_Cuenta para ver si realizamos un update o un insert.
			-- Esto es porque cuando se crea la Cuenta hay un trigger asociado que genera el APIKey en la tabla Parametro_Cuenta.

			SELECT @idParametroCuenta = id_parametro_cuenta FROM Parametro_Cuenta WHERE id_cuenta = @idCuentaTmp

			IF (@idParametroCuenta IS NULL) 
				BEGIN
					INSERT INTO Parametro_Cuenta (    id_cuenta, flag_reporte_comercio, fecha_alta, usuario_alta, fecha_modificacion, usuario_modificacion, fecha_baja, usuario_baja, version,        api_key, api_key_pruebas, id_cuenta_pruebas)
										  VALUES ( @idCuentaTmp,                     0,  GETDATE(), 'API_Key_SP',               NULL,                 NULL,       NULL,         NULL,       0, @apiKeyPruebas,  @apiKeyPruebas, @idCuentaTmp)
				END
			ELSE
				BEGIN
					UPDATE Parametro_Cuenta SET  fecha_modificacion = GETDATE() ,usuario_modificacion = 'API_Key_SP' ,api_key = @apiKeyPruebas ,api_key_pruebas = @apiKeyPruebas WHERE id_parametro_cuenta = @idParametroCuenta
				END


		END

		SELECT @idCuentaTmp AS id_cuenta, '00000' as status
		
		COMMIT TRANSACTION

END TRY

BEGIN CATCH
	
	PRINT ERROR_MESSAGE();
	
	IF (@@TRANCOUNT != 0)
		ROLLBACK TRANSACTION
    
	SELECT @idCuentaTmp AS id_cuenta, '2106' as status

END CATCH;

END

GO
/****** Object:  StoredProcedure [dbo].[SP_Registrar_Ajuste]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SP_Registrar_Ajuste] (            
    @Id_cuenta INT=NULL,  
    @Monto decimal(12, 2)=NULL,  
    @Id_codigoOperacion INT=NULL,  
    @Id_MotivoAjuste INT=NULL,  
    @Id_TipoOrigenMovimiento INT=NULL,  
    @Id_TipoMovimiento INT=NULL,  
    @usuario VARCHAR(20)=NULL,  
    @Id_log_proceso INT=NULL,  
    @canal INT=NULL,
    @Msg VARCHAR(max) OUTPUT,  
    @CodRet VARCHAR(max) OUTPUT  
)  
  
AS   
   
  DECLARE @v_idAjuste INT;  
  DECLARE @Flag_OK_CV INT;  
  DECLARE @tipo_mov_cred INT;  
  DECLARE @tipo_mov_deb INT  
  DECLARE @cod_oper_AJN INT;  
  DECLARE @cod_oper_AJP INT  
  

BEGIN
     
SET NOCOUNT ON            
        
BEGIN TRANSACTION;

 BEGIN TRY   
     
	 --1. Establecer valores para salida correcta 
	 SET  @CodRet='00000'; 

	 SELECT @Msg = mensaje from Mensaje  
     WHERE codigo_mensaje = 0  
     
	 --2. Validaciones
     IF (@Id_cuenta IS NULL OR @Id_cuenta = 0 OR                
		 @Monto IS NULL OR @Monto = 0  OR          
		 @Id_codigoOperacion IS NULL OR @Id_codigoOperacion = 0 OR  @Id_codigoOperacion not in (4,5) or
		 @Id_MotivoAjuste IS NULL OR @Id_MotivoAjuste = 0 OR    
		 @Id_TipoOrigenMovimiento IS NULL OR @Id_TipoOrigenMovimiento = 0 OR   
		 @Id_TipoMovimiento IS NULL OR @Id_TipoMovimiento = 0 OR @Id_TipoMovimiento not in (57,58) or            
		 @usuario IS NULL OR @usuario = '' OR
		 @canal IS NULL)  
  
		 BEGIN  
  
		 SET @CodRet='2059'  
       
		 SELECT @Msg = mensaje from Mensaje  
		 WHERE codigo_mensaje = 2059  
  
		 END  
  
      ELSE  
  
		 BEGIN  
     
		  --3. Validacion de parametros (tipo movimiento y codigo de operacion)
		  SELECT @tipo_mov_cred=tpo_1.id_tipo, @tipo_mov_deb=tpo_2.id_tipo 
		  FROM configurations.dbo.Tipo tpo_1 , configurations.dbo.Tipo tpo_2
		  WHERE tpo_1.codigo = 'MOV_CRED' AND tpo_1.id_grupo_tipo = 16   
		  AND   tpo_2.codigo = 'MOV_DEB' AND tpo_2.id_grupo_tipo = 16

		  SELECT @cod_oper_AJN=Cod_1.id_codigo_operacion , @cod_oper_AJP=Cod_2.id_codigo_operacion
		  FROM Configurations.dbo.Codigo_Operacion Cod_1, Configurations.dbo.Codigo_Operacion Cod_2
		  WHERE Cod_1.codigo_operacion='AJN'  AND Cod_2.codigo_operacion='AJP'  
  
		  IF ((@Id_TipoMovimiento=@tipo_mov_cred and @monto<0) or (@Id_TipoMovimiento=@tipo_mov_deb and @monto>0)  
			  or (@Id_codigoOperacion=@cod_oper_AJN and @monto>0) or (@Id_codigoOperacion=@cod_oper_AJP and @monto<0))  
  
				  BEGIN
				  
				  SET @CodRet='2057'  
       
				  SELECT @Msg = mensaje from Mensaje WHERE codigo_mensaje = 2057;  
		    
				  END       
           ELSE  
           
			       BEGIN
				     
					 --4. Insertar en cuenta virtual
					 EXECUTE @Flag_OK_CV=Configurations.dbo.Actualizar_Cuenta_Virtual   
					   @Monto,   
					   null,   
					   @Monto,   
					   null,   
					   null,  
					   null,  
					   @Id_cuenta,  
					   @Usuario,   
					   @Id_TipoMovimiento, 
					   @Id_TipoOrigenMovimiento,   
					   @Id_log_proceso;  

					   --5. Generar ID para nuevo ajuste     
					   SET @v_idAjuste = (SELECT ISNULL(MAX(id_ajuste),0) + 1 FROM Configurations.dbo.Ajuste);  


						--6. Insertar en ajuste
					   INSERT INTO [dbo].[Ajuste](  
						  [id_ajuste],  
						  [id_codigo_operacion],  
						  [id_cuenta],  
						  [id_motivo_ajuste],  
						  [monto],  
						  [estado_ajuste],  
						  [fecha_alta],  
						  [usuario_alta],  
						  [version])  
						VALUES(@v_idAjuste,   
						  @Id_codigoOperacion, 
						  @Id_cuenta,  
						  @Id_MotivoAjuste,
						  @Monto,  
						  'TX_APROBADA',  
						  GETDATE(),  
						  @usuario,  
						  0);
					END	  
						
				END
     
	 COMMIT TRANSACTION;  
 
 END TRY  


  
 BEGIN CATCH   
 
	    
     IF (@@TRANCOUNT > 0)
   

		ROLLBACK TRANSACTION;     
    
		--7. Devolucion de mensaje y codigo para para deshacer cuenta virtual y ajuste en la operacion
		SET  @CodRet='2057' 
		SELECT @Msg = mensaje from configurations.dbo.Mensaje WHERE codigo_mensaje = 2057  
	
 END CATCH  
   
            
 END
GO
/****** Object:  StoredProcedure [dbo].[w_Actualizar_Cuenta_Virtual]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 

CREATE PROCEDURE [dbo].[w_Actualizar_Cuenta_Virtual] ( 
             @monto_disponible decimal (12,2) = NULL,
             @validacion_disponible decimal (12,2) = NULL,
             @monto_saldo_en_cuenta decimal (12,2) = NULL,
             @validacion_saldo_en_cuenta decimal (12,2) = NULL,
             @monto_saldo_en_revision decimal (12,2) = NULL,
             @validacion_saldo_en_revision decimal (12,2) = NULL,
             @id_cuenta int,
             @usuario_alta varchar (20) = NULL,
             @id_tipo_movimiento int,
             @id_tipo_origen_movimiento int,
             @id_log_proceso int = NULL
)            AS
BEGIN

    DECLARE @ret INTEGER;

    EXEC @ret = Actualizar_Cuenta_Virtual 
             @monto_disponible,
             @validacion_disponible,
             @monto_saldo_en_cuenta,
             @validacion_saldo_en_cuenta,
             @monto_saldo_en_revision,
             @validacion_saldo_en_revision,
             @id_cuenta,
             @usuario_alta,
             @id_tipo_movimiento,
             @id_tipo_origen_movimiento,
             @id_log_proceso;

    
    SELECT @ret as RetCode;
END
GO
/****** Object:  Table [dbo].[Accion_Limite]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Accion_Limite](
	[id_accion_limite] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_tipo_limite] [int] NOT NULL,
	[id_tipo_aplicacion_limite] [int] NOT NULL,
	[id_tipo_accion_limite] [int] NOT NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL DEFAULT ((0)),
PRIMARY KEY CLUSTERED 
(
	[id_accion_limite] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ACL_BANCO]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ACL_BANCO](
	[id_acl_banco] [int] NOT NULL,
	[id_banco] [int] NOT NULL,
	[description] [varchar](100) NOT NULL,
	[CN] [varchar](512) NOT NULL,
	[fecha_desde] [datetime] NOT NULL,
	[fecha_hasta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL DEFAULT (NULL),
	[usuario_modificacion] [varchar](20) NULL DEFAULT (NULL),
	[fecha_baja] [datetime] NULL DEFAULT (NULL),
	[usuario_baja] [varchar](20) NULL DEFAULT (NULL),
	[version] [int] NOT NULL DEFAULT ('0'),
PRIMARY KEY CLUSTERED 
(
	[id_acl_banco] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Actividad_AFIP]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Actividad_AFIP](
	[id_actividad_AFIP] [int] NOT NULL,
	[codigo_actividad_AFIP] [varchar](6) NOT NULL,
	[descripcion] [varchar](256) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Actividad_AFIP_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Actividad_AFIP] PRIMARY KEY CLUSTERED 
(
	[id_actividad_AFIP] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Actividad_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Actividad_Cuenta](
	[id_cuenta] [int] NOT NULL,
	[actividad_declarada] [varchar](50) NULL,
	[id_actividad_AFIP] [int] NULL,
	[id_rubro] [int] NULL,
	[id_estado_actividad] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[fecha_validacion] [datetime] NULL,
	[usuario_validador] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Actividad_Cuenta_version]  DEFAULT ((0)),
	[id_actividad_cuenta] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[flag_vigente] [bit] NOT NULL DEFAULT ((0)),
 CONSTRAINT [PK_Actividad_Cuenta] PRIMARY KEY CLUSTERED 
(
	[id_actividad_cuenta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Actividad_MP_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Actividad_MP_Cuenta](
	[id_actividad_mp] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_mp_cuenta] [int] NOT NULL,
	[cant_tx_dia] [int] NULL CONSTRAINT [DF_Actividad_MP_cant_tx_di]  DEFAULT ((0)),
	[monto_tx_dia] [decimal](12, 2) NULL CONSTRAINT [DF_Actividad_MP_monto_tx_d]  DEFAULT ((0)),
	[fecha_compra] [datetime] NOT NULL,
	[id_log_proceso] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NULL CONSTRAINT [DF_Actividad_MP_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Actividad_MP_Cuenta] PRIMARY KEY CLUSTERED 
(
	[id_actividad_mp] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Actividad_Transaccional_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Actividad_Transaccional_Cuenta](
	[id_actividad_cuenta] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[cant_tx_dia_TC] [int] NULL CONSTRAINT [DF_Actividad_Transaccional__cant_tx_di]  DEFAULT ((0)),
	[cant_tx_dia_TD] [int] NULL CONSTRAINT [DF_Actividad_Transaccional_Cuenta_cant_tx_dia_TD]  DEFAULT ((0)),
	[cant_tx_dia_cupon] [int] NULL CONSTRAINT [DF_Actividad_Transaccional_Cuenta_cant_tx_dia_cupon]  DEFAULT ((0)),
	[cant_tx_dia_cupon_vencido] [int] NULL CONSTRAINT [DF_Actividad_Transaccional_Cuenta_cant_tx_dia_cupon_vencido]  DEFAULT ((0)),
	[cant_tx_dia_cashOut] [int] NULL CONSTRAINT [DF_Actividad_Transaccional_Cuenta_cant_tx_dia_cashOut]  DEFAULT ((0)),
	[monto_tx_dia_TC] [decimal](12, 2) NULL CONSTRAINT [DF_Actividad_Transaccional__monto_tx_d]  DEFAULT ((0)),
	[monto_tx_dia_TD] [decimal](12, 2) NULL CONSTRAINT [DF_Actividad_Transaccional_Cuenta_monto_tx_dia_TD]  DEFAULT ((0)),
	[monto_tx_dia_cupon] [decimal](12, 2) NULL CONSTRAINT [DF_Actividad_Transaccional_Cuenta_monto_tx_dia_cupon]  DEFAULT ((0)),
	[monto_tx_dia_cupon_vencido] [decimal](12, 2) NULL CONSTRAINT [DF_Actividad_Transaccional_Cuenta_monto_tx_dia_cupon_vencido]  DEFAULT ((0)),
	[monto_tx_dia_cashOut] [decimal](12, 2) NULL CONSTRAINT [DF_Actividad_Transaccional_Cuenta_monto_tx_dia_cashOut]  DEFAULT ((0)),
	[fecha_procesada] [datetime] NOT NULL,
	[id_log_proceso] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Actividad_Transaccional_Cuenta_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Actividad_Transaccional_] PRIMARY KEY CLUSTERED 
(
	[id_actividad_cuenta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Acumulador_Promociones]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Acumulador_Promociones](
	[id_acumulador_promociones] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_promocion] [int] NOT NULL,
	[fecha_transaccion] [datetime] NULL,
	[cuenta_transaccion] [int] NULL,
	[importe_total_tx] [decimal](12, 2) NULL,
	[cantidad_tx] [int] NULL,
 CONSTRAINT [PK_Acumulador_Promociones] PRIMARY KEY CLUSTERED 
(
	[id_acumulador_promociones] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Ajuste]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Ajuste](
	[id_ajuste] [int] NOT NULL,
	[id_codigo_operacion] [int] NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[monto] [decimal](12, 2) NOT NULL,
	[id_motivo_ajuste] [int] NOT NULL,
	[estado_ajuste] [varchar](20) NOT NULL CONSTRAINT [DF_Ajuste_estado_ajuste]  DEFAULT ('Aprobado'),
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Ajuste_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Ajuste] PRIMARY KEY CLUSTERED 
(
	[id_ajuste] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Analisis_Saldos_Tmp]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Analisis_Saldos_Tmp](
	[I] [int] NOT NULL,
	[tipo] [char](3) NOT NULL,
	[id_char] [char](36) NULL,
	[id_int] [int] NULL,
	[id_cuenta] [int] NULL,
	[importe] [decimal](12, 2) NULL,
	[fecha] [datetime] NULL,
	[id_log_proceso] [int] NULL,
	[fecha_inicio_ejecucion] [datetime] NULL,
	[fecha_fin_ejecucion] [datetime] NULL,
	[id_log_movimiento] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Apariencia_Boton]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Apariencia_Boton](
	[id_apariencia_boton] [int] NOT NULL,
	[descripcion] [varchar](20) NULL,
	[color_fondo] [varchar](20) NULL,
	[color_fuente] [varchar](20) NULL,
	[color_borde] [varchar](20) NULL,
	[fuente] [varchar](20) NULL,
	[tamanio] [varchar](20) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Apariencia_Boton_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Apariencia_Boton] PRIMARY KEY CLUSTERED 
(
	[id_apariencia_boton] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Banco]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Banco](
	[id_banco] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[codigo] [varchar](3) NULL,
	[denominacion] [varchar](40) NOT NULL,
	[logo] [varchar](200) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Banco_version]  DEFAULT ((0)),
	[flag_cliente_unico] [bit] NOT NULL CONSTRAINT [DF_Banco_flag_cliente_unico]  DEFAULT ((0)),
	[flag_adherido_billetera] [bit] NOT NULL CONSTRAINT [DF_Banco_flag_adherido_billetera]  DEFAULT ((0)),
	[flag_envia_relacion] [bit] NOT NULL CONSTRAINT [DF_Banco_flag_envia_relacion]  DEFAULT ((0)),
	[id_tipo_acreditacion] [int] NOT NULL CONSTRAINT [DF_Banco_tipo_acreditacion]  DEFAULT ((62)),
	[flag_permite_preautorizacion] [bit] NULL,
	[flag_red_debito] [bit] NULL,
	[descripcion_corta] [varchar](50) NULL,
	[codigo_banco_link] [varchar](4) NULL,
 CONSTRAINT [PK_Banco] PRIMARY KEY CLUSTERED 
(
	[id_banco] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY],
 CONSTRAINT [UQ__Banco__40F9A206B2E48EE4] UNIQUE NONCLUSTERED 
(
	[codigo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Bin_Banco_Medio_Pago]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Bin_Banco_Medio_Pago](
	[id_bin_banco_mp] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[bin] [varchar](8) NOT NULL,
	[id_banco] [int] NOT NULL,
	[id_medio_pago] [int] NOT NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NULL DEFAULT ((0)),
PRIMARY KEY CLUSTERED 
(
	[id_bin_banco_mp] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY],
 CONSTRAINT [UQ_Bin_Banco_Medio_Pago] UNIQUE NONCLUSTERED 
(
	[bin] ASC,
	[id_banco] ASC,
	[id_medio_pago] ASC,
	[fecha_baja] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Boton]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Boton](
	[id_boton] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_tipo_boton] [int] NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[descripcion] [varchar](max) NULL,
	[monto_desde] [decimal](12, 2) NOT NULL,
	[monto_hasta] [decimal](12, 2) NULL,
	[imagen] [varchar](256) NULL,
	[fuente] [varchar](max) NULL,
	[flag_todos_mp] [bit] NOT NULL,
	[url_pago_exitoso] [varchar](max) NULL,
	[url_pago_no_exitoso] [varchar](max) NULL,
	[id_tipo_concepto_boton] [int] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
SET ANSI_PADDING OFF
ALTER TABLE [dbo].[Boton] ADD [color_borde] [varchar](20) NULL
ALTER TABLE [dbo].[Boton] ADD [color_fondo] [varchar](20) NULL
ALTER TABLE [dbo].[Boton] ADD [color_fuente] [varchar](20) NULL
ALTER TABLE [dbo].[Boton] ADD [fecha_alta] [datetime] NULL
ALTER TABLE [dbo].[Boton] ADD [fecha_baja] [datetime] NULL
ALTER TABLE [dbo].[Boton] ADD [fecha_modificacion] [datetime] NULL
ALTER TABLE [dbo].[Boton] ADD [flag_tipo_monto] [bit] NULL
ALTER TABLE [dbo].[Boton] ADD [tamanio] [varchar](20) NULL
ALTER TABLE [dbo].[Boton] ADD [usuario_alta] [varchar](20) NULL
ALTER TABLE [dbo].[Boton] ADD [usuario_baja] [varchar](20) NULL
ALTER TABLE [dbo].[Boton] ADD [usuario_modificacion] [varchar](20) NULL
ALTER TABLE [dbo].[Boton] ADD [version] [int] NOT NULL CONSTRAINT [DF_Boton_version]  DEFAULT ((0))
SET ANSI_PADDING ON
ALTER TABLE [dbo].[Boton] ADD [id_publico_boton] [varchar](64) NULL
ALTER TABLE [dbo].[Boton] ADD [fuente_tipo] [varchar](20) NULL
ALTER TABLE [dbo].[Boton] ADD [titulo] [varchar](255) NULL
ALTER TABLE [dbo].[Boton] ADD [texto] [varchar](10) NULL
ALTER TABLE [dbo].[Boton] ADD [flag_tipo_stock] [bit] NOT NULL CONSTRAINT [DF_flag_tipo_stock]  DEFAULT ((0))
ALTER TABLE [dbo].[Boton] ADD [logo] [varchar](256) NULL
ALTER TABLE [dbo].[Boton] ADD [stock] [int] NULL
SET ANSI_PADDING OFF
ALTER TABLE [dbo].[Boton] ADD [alto_boton] [varchar](20) NULL
ALTER TABLE [dbo].[Boton] ADD [ancho_boton] [varchar](20) NULL
ALTER TABLE [dbo].[Boton] ADD [id_apariencia_boton] [int] NULL
ALTER TABLE [dbo].[Boton] ADD [flag_reintento_tx] [bit] NULL
 CONSTRAINT [PK_Boton] PRIMARY KEY CLUSTERED 
(
	[id_boton] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Cambio_Pendiente]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [dbo].[Cambio_Pendiente](
	[id_cambio_pendiente] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[id_estado_cambio] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Cambio_Pendiente_version]  DEFAULT ((0)),
	[fecha_resolucion] [datetime] NULL
) ON [PRIMARY]
SET ANSI_PADDING ON
ALTER TABLE [dbo].[Cambio_Pendiente] ADD [usuario_resolucion] [varchar](20) NULL
 CONSTRAINT [PK_Cambio_Pendiente] PRIMARY KEY CLUSTERED 
(
	[id_cambio_pendiente] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Canal_Adhesion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Canal_Adhesion](
	[id_canal] [int] NOT NULL,
	[nombre] [varchar](20) NOT NULL,
	[nivel_riesgo] [varchar](20) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_canal_adhesion_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Canal_Adhesion] PRIMARY KEY CLUSTERED 
(
	[id_canal] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Cargo]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Cargo](
	[id_cargo] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_tipo_medio_pago] [int] NULL,
	[id_tipo_cuenta] [int] NULL,
	[id_base_de_calculo] [int] NULL,
	[id_tipo_aplicacion] [int] NULL,
	[valor] [decimal](12, 2) NULL,
	[flag_estado] [bit] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Cargo_version]  DEFAULT ((0)),
	[flag_permite_baja] [bit] NOT NULL,
	[id_tipo_cargo] [int] NULL,
	[grupo_cargo] [int] NULL CONSTRAINT [DF_Cargo_grupo_cargo]  DEFAULT ((1)),
 CONSTRAINT [PK_Cargo] PRIMARY KEY CLUSTERED 
(
	[id_cargo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Cargo_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Cargo_Cuenta](
	[id_cargo_cuenta] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cargo] [int] NULL,
	[id_cuenta] [int] NULL,
	[id_tipo_aplicacion] [int] NULL,
	[valor] [decimal](12, 2) NULL,
	[fecha_inicio_vigencia] [datetime] NULL,
	[fecha_fin_vigencia] [datetime] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Cargo_Cuenta_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Cargo_Cuenta] PRIMARY KEY CLUSTERED 
(
	[id_cargo_cuenta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Cargos_Por_Transaccion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Cargos_Por_Transaccion](
	[id_cargo_transaccion] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cargo] [int] NOT NULL,
	[id_transaccion] [char](36) NOT NULL,
	[monto_calculado] [decimal](12, 2) NOT NULL,
	[valor_aplicado] [decimal](12, 2) NOT NULL,
	[id_tipo_aplicacion] [int] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL CONSTRAINT [DF_Cargos_Por_Transaccion_fecha_modificacion]  DEFAULT (NULL),
	[usuario_modificacion] [varchar](20) NULL CONSTRAINT [DF_Cargos_Por_Transaccion_usuario_modificacion]  DEFAULT (NULL),
	[fecha_baja] [datetime] NULL CONSTRAINT [DF_Cargos_Por_Transaccion_fecha_baja]  DEFAULT (NULL),
	[usuario_baja] [varchar](20) NULL CONSTRAINT [DF_Cargos_Por_Transaccion_usuario_baja]  DEFAULT (NULL),
	[version] [int] NOT NULL CONSTRAINT [DF_Cargos_Por_Transaccion_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Cargos_Por_Transaccion] PRIMARY KEY CLUSTERED 
(
	[id_cargo_transaccion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[CBU_Pendientes_Tmp]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[CBU_Pendientes_Tmp](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[cuit] [varchar](11) NULL,
	[entidad_solicitante] [varchar](3) NULL,
	[id_cuenta] [int] NULL,
	[fecha_inicio_pendiente] [date] NULL,
	[fecha_vencimiento] [date] NULL,
	[entidad_registrada] [varchar](3) NULL,
	[razon_social] [varchar](100) NULL,
	[cbu] [varchar](22) NULL,
	[id_banco] [int] NULL,
	[tipo_acreditacion] [varchar](14) NULL,
	[motivo] [varchar](12) NULL,
	[accion] [varchar](10) NULL,
 CONSTRAINT [PK_CBU_Pendientes_Tmp] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Ciclo_Facturacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Ciclo_Facturacion](
	[id_ciclo_facturacion] [int] NOT NULL,
	[dia_de_ejecucion] [int] NOT NULL,
	[dia_inicio] [int] NOT NULL,
	[dia_tope_incluido] [int] NOT NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Ciclo_Facturacion_version]  DEFAULT ((0)),
	[meses_desplazamiento] [int] NOT NULL CONSTRAINT [DF_Ciclo_Facturacion__meses_desp]  DEFAULT ((0)),
 CONSTRAINT [PK_Ciclo_Facturacion] PRIMARY KEY CLUSTERED 
(
	[id_ciclo_facturacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Cliente_Unico]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Cliente_Unico](
	[Cliente_Unico_Id] [int] NOT NULL,
	[tipo_identificacion] [varchar](20) NULL,
	[numero_identificacion] [varchar](20) NULL,
	[sexo] [varchar](1) NULL,
	[banco] [char](3) NULL,
	[id_medio_pago] [int] NULL,
	[nombre] [varchar](50) NULL,
	[numero_tarjeta] [varchar](20) NULL,
	[fecha_vencimiento] [varchar](6) NULL,
	[fecha_nacimiento] [datetime] NULL,
	[numero_cuit] [varchar](11) NULL,
	[telefono_movil] [varchar](10) NULL,
	[telefono_fijo] [varchar](10) NULL,
	[calle] [varchar](30) NULL,
	[numero] [varchar](10) NULL,
	[piso] [varchar](10) NULL,
	[departamento] [varchar](10) NULL,
	[id_provincia] [smallint] NULL,
	[codigo_postal] [varchar](20) NULL,
	[nacionalidad] [varchar](20) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
 CONSTRAINT [PK_Cliente_Unico_Id] PRIMARY KEY CLUSTERED 
(
	[Cliente_Unico_Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Codigo_Operacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Codigo_Operacion](
	[id_codigo_operacion] [int] NOT NULL,
	[codigo_operacion] [varchar](20) NULL,
	[descripcion] [varchar](20) NULL,
	[signo] [char](1) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Codigo_Operacion_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Codigo_Operacion] PRIMARY KEY CLUSTERED 
(
	[id_codigo_operacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Codigo_Operacion_Medio_Pago]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Codigo_Operacion_Medio_Pago](
	[id_codigo_operacion_mp] [int] NOT NULL,
	[id_medio_pago] [int] NULL,
	[id_codigo_operacion] [int] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Codigo_Operacion_Medio_Pago_version]  DEFAULT ((0)),
	[campo_mp_1] [varchar](10) NULL,
	[valor_1] [varchar](15) NULL,
	[campo_mp_2] [varchar](10) NULL,
	[valor_2] [varchar](15) NULL,
	[campo_mp_3] [varchar](10) NULL,
	[valor_3] [varchar](15) NULL,
 CONSTRAINT [PK_Codigo_Operacion_Medio_Pago] PRIMARY KEY CLUSTERED 
(
	[id_codigo_operacion_mp] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Codigo_Respuesta_Resolutor]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [dbo].[Codigo_Respuesta_Resolutor](
	[id] [int] NOT NULL,
	[id_resolutor] [int] NOT NULL,
	[codigo_respuesta] [varchar](20) NOT NULL,
	[descripcion] [varchar](200) NULL,
	[id_mensaje] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Codigo_Respuesta_Resolutor_version]  DEFAULT ((0)),
 CONSTRAINT [PK_id_Codigo_Respuesta_Resolutor] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Color_Boton]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Color_Boton](
	[id_color_boton] [int] NOT NULL,
	[descripcion] [varchar](20) NULL,
	[codigo_color] [varchar](20) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Color_Boton_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Color_Boton] PRIMARY KEY CLUSTERED 
(
	[id_color_boton] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Comercio_Prisma]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Comercio_Prisma](
	[cuit] [varchar](11) NOT NULL,
	[id_banco] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Conciliacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Conciliacion](
	[id_conciliacion] [int] NOT NULL,
	[id_transaccion] [char](36) NULL,
	[id_log_paso] [int] NULL,
	[flag_aceptada_marca] [bit] NOT NULL CONSTRAINT [DF_Conciliacion_flag_aceptada_marca]  DEFAULT ((0)),
	[flag_conciliada] [bit] NOT NULL CONSTRAINT [DF_Conciliacion_flag_conciliada]  DEFAULT ((0)),
	[id_conciliacion_manual] [int] NULL,
	[flag_contracargo] [bit] NOT NULL CONSTRAINT [DF_Conciliacion_flag_contracargo]  DEFAULT ((0)),
	[id_disputa] [int] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Conciliacion_version]  DEFAULT ((0)),
	[flag_distribuida] [bit] NOT NULL CONSTRAINT [DF_Conciliacion_flag_distribuida]  DEFAULT ((0)),
	[id_movimiento_mp] [int] NULL,
	[flag_notificado] [bit] NOT NULL CONSTRAINT [DF_Conciliacion_flag_notificado]  DEFAULT ((0)),
 CONSTRAINT [PK_Conciliacion] PRIMARY KEY CLUSTERED 
(
	[id_conciliacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Conciliacion_Manual]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Conciliacion_Manual](
	[id_conciliacion_manual] [int] NOT NULL,
	[id_transaccion] [char](36) NULL,
	[importe] [decimal](12, 2) NULL,
	[moneda] [int] NULL,
	[cantidad_cuotas] [int] NULL,
	[nro_tarjeta] [varchar](50) NULL,
	[codigo_barra] [varchar](50) NULL,
	[fecha_movimiento] [datetime] NULL,
	[nro_autorizacion] [varchar](50) NULL,
	[nro_cupon] [varchar](50) NULL,
	[nro_agrupador_boton] [varchar](50) NULL,
	[flag_aceptada_marca] [bit] NULL,
	[flag_contracargo] [bit] NULL,
	[flag_conciliado_manual] [bit] NOT NULL,
	[flag_procesado] [bit] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Conciliacion_Manual_version]  DEFAULT ((0)),
	[cargos_boton_por_movimiento] [decimal](12, 2) NULL,
	[impuestos_boton_por_movimiento] [decimal](12, 2) NULL,
	[cargos_marca_por_movimiento] [decimal](12, 2) NULL,
	[fecha_pago] [datetime] NULL,
	[id_log_paso] [int] NULL,
	[signo_cargos_marca_por_movimiento] [varchar](1) NULL,
	[id_movimiento_mp] [int] NULL,
 CONSTRAINT [PK_Conciliacion_Manual] PRIMARY KEY CLUSTERED 
(
	[id_conciliacion_manual] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Configuracion_Conciliacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Configuracion_Conciliacion](
	[id_parametro] [int] NOT NULL,
	[id_medio_pago] [int] NOT NULL,
	[parametro] [varchar](50) NULL,
	[campo_Transactions] [varchar](50) NULL,
	[campo_Mov_pres_mp] [varchar](50) NULL,
	[formato_parametro] [varchar](15) NULL,
	[pos_inicial_mascara] [int] NULL,
	[cantidad_pos_mascara] [int] NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NULL DEFAULT ((0)),
PRIMARY KEY CLUSTERED 
(
	[id_parametro] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Contacto_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Contacto_Cuenta](
	[id_contacto] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[nombre_contacto] [varchar](50) NULL,
	[apellido_contacto] [varchar](50) NULL,
	[telefono_movil] [varchar](10) NOT NULL,
	[id_tipo_identificacion] [int] NOT NULL,
	[numero_identificacion] [varchar](20) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Contacto_Cuenta_version]  DEFAULT ((0)),
	[id_operador_celular] [int] NULL,
 CONSTRAINT [PK_Contacto_Cuenta] PRIMARY KEY CLUSTERED 
(
	[id_contacto] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Control_Cuenta_Virtual]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Control_Cuenta_Virtual](
	[id_control] [int] NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[id_log_proceso] [int] NOT NULL,
	[disponible_anterior] [decimal](12, 2) NOT NULL,
	[monto_disponible] [decimal](12, 2) NOT NULL,
	[disponible_anteriorMASmonto_disponible] [decimal](12, 2) NOT NULL,
	[disponible_actual] [decimal](12, 2) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
 CONSTRAINT [PK_Control_Cuenta_Virtual] PRIMARY KEY CLUSTERED 
(
	[id_control] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Control_Liquidacion_Disponible]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Control_Liquidacion_Disponible](
	[id_control] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[fecha_base_de_cashout] [date] NULL,
	[fecha_de_cashout] [date] NULL,
	[id_cuenta] [int] NULL,
	[id_codigo_operacion] [int] NULL,
	[importe] [decimal](12, 2) NULL,
 CONSTRAINT [PK_Control_Liquidacion_Disponible] PRIMARY KEY CLUSTERED 
(
	[id_control] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Control_Liquidacion_Facturacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Control_Liquidacion_Facturacion](
	[I_control] [int] IDENTITY(1,1) NOT NULL,
	[id_cuenta] [int] NULL,
	[numero_CUIT] [varchar](11) NULL,
	[eMail] [varchar](50) NULL,
	[saldo_pendiente] [decimal](12, 2) NULL,
	[saldo_revision] [decimal](12, 2) NULL,
	[saldo_disponible] [decimal](12, 2) NULL,
	[suma_cargos_aurus] [decimal](12, 2) NULL,
	[tipo_comprobante_fact] [char](1) NULL,
	[total_liquidado] [decimal](12, 2) NULL,
	[tipo_comprobante_liqui] [char](1) NULL,
	[posee_diferencia] [bit] NULL,
	[id_ciclo_facturacion] [int] NULL,
	[anio] [int] NULL,
	[mes] [int] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
 CONSTRAINT [PK_Control_Liquidacion_Facturacion] PRIMARY KEY CLUSTERED 
(
	[I_control] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Cuenta](
	[id_cuenta] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_tipo_cuenta] [int] NOT NULL,
	[denominacion1] [varchar](50) NOT NULL,
	[denominacion2] [varchar](50) NOT NULL,
	[id_tipo_identificacion] [int] NULL,
	[numero_identificacion] [varchar](20) NULL,
	[numero_CUIT] [varchar](11) NULL,
	[sexo] [varchar](1) NULL,
	[id_nacionalidad] [int] NULL,
	[fecha_nacimiento] [datetime] NULL,
	[id_canal] [int] NOT NULL,
	[id_estado_cuenta] [int] NOT NULL,
	[id_version_tyc] [int] NULL,
	[flag_envio_novedades] [bit] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Cuenta_version]  DEFAULT ((0)),
	[telefono_movil] [varchar](10) NULL,
	[telefono_fijo] [varchar](10) NULL,
	[flag_cambio_pendiente] [bit] NULL DEFAULT ((0)),
	[id_operador_celular] [int] NULL,
	[flag_informado_a_facturacion] [bit] NULL CONSTRAINT [DF_Cuenta_flag_informado_a_facturacion]  DEFAULT ((0)),
	[id_banco_adhesion] [int] NULL,
	[flag_factor_validacion] [bit] NULL DEFAULT ((0)),
 CONSTRAINT [PK_Cuenta] PRIMARY KEY CLUSTERED 
(
	[id_cuenta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Cuenta_Virtual]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Cuenta_Virtual](
	[id_cuenta_virtual] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[saldo_en_cuenta] [decimal](12, 2) NOT NULL CONSTRAINT [DF_Cuenta_Virtual_saldo_en_c]  DEFAULT ((0)),
	[saldo_en_revision] [decimal](12, 2) NOT NULL CONSTRAINT [DF_Cuenta_Virtual_saldo_en_r]  DEFAULT ((0)),
	[disponible] [decimal](12, 2) NOT NULL CONSTRAINT [DF_Cuenta_Virtual_disponible]  DEFAULT ((0)),
	[id_proceso_modificacion] [int] NULL,
	[id_tipo_cashout] [int] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](100) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](100) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Cuenta_Virtual_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Cuenta_Virtual] PRIMARY KEY CLUSTERED 
(
	[id_cuenta_virtual] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[CUIT_A_Informar_Tmp]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[CUIT_A_Informar_Tmp](
	[cuit] [varchar](50) NULL,
	[id_cuenta] [int] NULL,
	[codigo_banco] [varchar](3) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[CUIT_Condicionado]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[CUIT_Condicionado](
	[id_cuit_condicionado] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[numero_CUIT] [varchar](11) NOT NULL,
	[id_banco] [int] NOT NULL,
	[fecha_inicio_vigencia] [date] NOT NULL,
	[fecha_fin_vigencia] [date] NOT NULL,
	[id_documento] [int] NOT NULL,
	[id_motivo_alta] [int] NOT NULL,
	[id_motivo_baja] [int] NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id_cuit_condicionado] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[cuit_multicuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[cuit_multicuenta](
	[id_cuit_multicuenta] [int] IDENTITY(1,1) NOT NULL,
	[numero_CUIT] [varchar](11) NOT NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL DEFAULT (NULL),
	[usuario_modificacion] [varchar](20) NULL DEFAULT (NULL),
	[fecha_baja] [datetime] NULL DEFAULT (NULL),
	[usuario_baja] [varchar](20) NULL DEFAULT (NULL),
	[version] [int] NOT NULL DEFAULT ((0)),
PRIMARY KEY CLUSTERED 
(
	[id_cuit_multicuenta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Cupones_tmp]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Cupones_tmp](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[id_conciliacion] [int] NOT NULL,
	[numero_cuenta] [int] NULL,
	[url] [varchar](256) NULL,
	[id_transaccion] [char](36) NULL,
	[e_mail] [varchar](64) NULL,
	[concepto] [varchar](255) NULL,
	[importe] [decimal](12, 2) NULL,
	[nombre_comprador] [varchar](48) NULL,
	[nombre_vendedor] [varchar](256) NULL,
 CONSTRAINT [PK_Id] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Dato_Pendiente]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [dbo].[Dato_Pendiente](
	[id_dato_pendiente] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cambio_pendiente] [int] NOT NULL,
	[id_registro_destino] [int] NOT NULL,
	[valor_pendiente] [varchar](100) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Dato_Pendiente_version]  DEFAULT ((0))
) ON [PRIMARY]
SET ANSI_PADDING ON
ALTER TABLE [dbo].[Dato_Pendiente] ADD [tabla_destino] [varchar](50) NOT NULL
ALTER TABLE [dbo].[Dato_Pendiente] ADD [campo_destino] [varchar](50) NOT NULL
ALTER TABLE [dbo].[Dato_Pendiente] ADD [id_tipo_cambio] [int] NULL
 CONSTRAINT [PK_Dato_Pendiente] PRIMARY KEY CLUSTERED 
(
	[id_dato_pendiente] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Detalle_Analisis_De_Saldo]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Detalle_Analisis_De_Saldo](
	[id_detalle] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[fecha_de_analisis] [datetime] NOT NULL,
	[tipo_movimiento] [char](3) NOT NULL,
	[id_char] [char](36) NULL,
	[id_int] [int] NULL,
	[id_cuenta] [int] NULL,
	[importe_movimiento] [decimal](12, 2) NULL,
	[fecha_movimiento] [datetime] NULL,
	[id_log_proceso] [int] NULL,
	[fecha_inicio_ejecucion] [datetime] NULL,
	[fecha_fin_ejecucion] [datetime] NULL,
	[id_log_movimiento] [int] NULL,
	[flag_impactar_en_saldo] [bit] NOT NULL,
	[impacto_en_saldo_ok] [bit] NULL,
 CONSTRAINT [PK_Detalle_Analisis_De_Saldo] PRIMARY KEY CLUSTERED 
(
	[id_detalle] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Detalle_Facturacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Detalle_Facturacion](
	[id_detalle_facturacion] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_item_facturacion] [int] NOT NULL,
	[id_transaccion] [char](36) NOT NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Detalle_Facturacion_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Detalle_Facturacion] PRIMARY KEY CLUSTERED 
(
	[id_detalle_facturacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Disputa]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Disputa](
	[id_disputa] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_tipo_origen] [int] NOT NULL,
	[id_transaccion] [char](36) NOT NULL,
	[id_transaccion_cuenta] [varchar](64) NOT NULL,
	[id_medio_pago] [int] NOT NULL,
	[fecha_notificacion_mp] [date] NOT NULL,
	[fecha_vencimiento_mp] [date] NOT NULL,
	[fecha_resolucion_mp] [date] NULL,
	[id_estado_resolucion_mp] [int] NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[fecha_notificacion_cuenta] [datetime] NULL,
	[fecha_vencimiento_cuenta] [datetime] NULL,
	[fecha_resolucion_cuenta] [datetime] NULL,
	[id_estado_resolucion_cuenta] [int] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Disputa_version]  DEFAULT ((0))
) ON [PRIMARY]
SET ANSI_PADDING OFF
ALTER TABLE [dbo].[Disputa] ADD [motivo_resolucion_cuenta] [varchar](256) NULL
ALTER TABLE [dbo].[Disputa] ADD [id_log_proceso] [int] NULL
SET ANSI_PADDING ON
ALTER TABLE [dbo].[Disputa] ADD [usuario_resolucion] [varchar](20) NULL
ALTER TABLE [dbo].[Disputa] ADD [id_motivo_estado] [int] NULL DEFAULT (NULL)
ALTER TABLE [dbo].[Disputa] ADD [id_notificacion_enviada] [int] NULL
 CONSTRAINT [PK_id_disputa] PRIMARY KEY CLUSTERED 
(
	[id_disputa] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Distribucion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Distribucion](
	[id_distribucion] [int] IDENTITY(1,1) NOT NULL,
	[id_transaccion] [char](36) NULL,
	[id_log_paso] [int] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
	[flag_procesado] [bit] NOT NULL,
	[fecha_distribucion] [datetime] NULL,
 CONSTRAINT [PK_Distribucion] PRIMARY KEY CLUSTERED 
(
	[id_distribucion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Distribucion_tmp]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Distribucion_tmp](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[id_transaccion] [char](36) NULL,
 CONSTRAINT [PK_Id_dist] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Doc_Disputa]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Doc_Disputa](
	[id_doc_disputa] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_documento] [int] NOT NULL,
	[id_disputa] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Doc_Disputa_version]  DEFAULT ((0)),
 CONSTRAINT [PK_id_doc_disputa] PRIMARY KEY CLUSTERED 
(
	[id_doc_disputa] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Doc_Situacion_Fiscal_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Doc_Situacion_Fiscal_Cuenta](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_documento] [int] NULL,
	[id_situacion_fiscal] [int] NULL,
	[id_estado_documento] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[fecha_validacion] [datetime] NULL,
	[usuario_validador] [varchar](50) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Doc_Situacion_Fiscal_Cuenta_version]  DEFAULT ((0)),
	[id_motivo_estado] [int] NULL,
 CONSTRAINT [PK_Doc_Situacion_Fiscal_Cue] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Documento]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Documento](
	[id_documento] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NULL,
	[id_tipo_documento] [int] NOT NULL,
	[documento] [varbinary](max) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Documento_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Documento] PRIMARY KEY CLUSTERED 
(
	[id_documento] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Documento_Por_Tipo]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Documento_Por_Tipo](
	[id] [int] NOT NULL,
	[id_tipo_condicion] [int] NULL,
	[id_tipo_documento] [int] NULL,
	[flag_requerido] [bit] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Documento_Por_Tipo_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Documento_Por_Tipo] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Domicilio_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Domicilio_Cuenta](
	[id_domicilio] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_tipo_domicilio] [int] NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[calle] [varchar](30) NOT NULL,
	[numero] [varchar](10) NOT NULL,
	[piso] [varchar](10) NULL,
	[departamento] [varchar](10) NULL,
	[id_localidad] [int] NULL,
	[id_provincia] [int] NULL,
	[codigo_postal] [varchar](20) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Domicilio_Cuenta_version]  DEFAULT ((0)),
	[flag_vigente] [bit] NOT NULL CONSTRAINT [DF_Domicilio_cuenta_flag_vigente]  DEFAULT ((0)),
 CONSTRAINT [PK_Domicilio_Cuenta] PRIMARY KEY CLUSTERED 
(
	[id_domicilio] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Estado]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Estado](
	[id_estado] [int] NOT NULL,
	[id_grupo_estado] [int] NOT NULL,
	[Codigo] [varchar](20) NOT NULL CONSTRAINT [DF_Estado_Codigo]  DEFAULT (''),
	[nombre] [varchar](50) NOT NULL,
	[descripcion] [varchar](200) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Estado_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Estado] PRIMARY KEY CLUSTERED 
(
	[id_estado] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Estado_Movimiento_MP]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Estado_Movimiento_MP](
	[id_estado_movimiento_mp] [int] NOT NULL,
	[id_medio_pago] [int] NULL,
	[campo_mp_1] [varchar](10) NULL,
	[valor_1] [varchar](15) NULL,
	[campo_mp_2] [varchar](10) NULL,
	[valor_2] [varchar](15) NULL,
	[campo_mp_3] [varchar](10) NULL,
	[valor_3] [varchar](15) NULL,
	[estado_movimiento] [char](1) NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Estado_Movimiento_MP_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Estado_Movimiento_MP] PRIMARY KEY CLUSTERED 
(
	[id_estado_movimiento_mp] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Feriados]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Feriados](
	[fecha] [datetime] NOT NULL,
	[esFeriado] [bit] NOT NULL,
	[diaSemana] [tinyint] NOT NULL,
	[diasEnMes] [tinyint] NOT NULL,
	[habilitado] [bit] NOT NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Fuente_Boton]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Fuente_Boton](
	[id_fuente_boton] [int] NOT NULL,
	[descripcion] [varchar](20) NULL,
	[valor] [varchar](150) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Fuente_Boton_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Fuente_Boton] PRIMARY KEY CLUSTERED 
(
	[id_fuente_boton] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Grupo_Estado]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Grupo_Estado](
	[id_grupo_estado] [int] NOT NULL,
	[codigo] [varchar](20) NOT NULL CONSTRAINT [DF_Grupo_Estado_codigo]  DEFAULT (''),
	[nombre] [varchar](50) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Grupo_Estado_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Grupo_Estado] PRIMARY KEY CLUSTERED 
(
	[id_grupo_estado] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Grupo_Motivo]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Grupo_Motivo](
	[id_grupo_motivo] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[codigo] [varchar](20) NOT NULL,
	[nombre] [varchar](50) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL DEFAULT (NULL),
	[usuario_modificacion] [varchar](20) NULL DEFAULT (NULL),
	[fecha_baja] [datetime] NULL DEFAULT (NULL),
	[usuario_baja] [varchar](20) NULL DEFAULT (NULL),
	[version] [int] NOT NULL DEFAULT ((0)),
PRIMARY KEY CLUSTERED 
(
	[id_grupo_motivo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Grupo_Notificacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Grupo_Notificacion](
	[id_grupo_notificacion] [int] NOT NULL,
	[nombre] [varchar](100) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Grupo_Notificacion_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Grupo_Notificacion] PRIMARY KEY CLUSTERED 
(
	[id_grupo_notificacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Grupo_Tipo]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Grupo_Tipo](
	[id_grupo_tipo] [int] NOT NULL,
	[nombre] [varchar](50) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Grupo_Tipo_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Grupo_Tipo] PRIMARY KEY CLUSTERED 
(
	[id_grupo_tipo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Historico_Mail_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Historico_Mail_Cuenta](
	[id_historico_mail_cuenta] [int] IDENTITY(1,1) NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[email] [varchar](50) NOT NULL,
	[id_estado_mail] [int] NOT NULL,
	[hash] [varchar](50) NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Historico_Mail_Cuenta_version]  DEFAULT ((0)),
 CONSTRAINT [PK_id_historico_mail_cuenta] PRIMARY KEY CLUSTERED 
(
	[id_historico_mail_cuenta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Impuesto]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Impuesto](
	[id_impuesto] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[descripcion] [varchar](60) NOT NULL,
	[flag_todas_provincias] [bit] NOT NULL CONSTRAINT [DF_Impuesto_flag_todas_provincias]  DEFAULT ((0)),
	[id_provincia] [int] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Impuesto_version]  DEFAULT ((0)),
	[codigo] [varchar](20) NOT NULL,
 CONSTRAINT [PK_Impuesto] PRIMARY KEY CLUSTERED 
(
	[id_impuesto] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Impuesto_General_MP]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Impuesto_General_MP](
	[fecha_pago_desde] [datetime] NULL,
	[fecha_pago_hasta] [datetime] NULL,
	[percepciones] [decimal](12, 2) NULL,
	[retenciones] [decimal](12, 2) NULL,
	[cargos] [decimal](12, 2) NULL,
	[otros_impuestos] [decimal](12, 2) NULL,
	[id_medio_pago] [int] NULL,
	[id_log_paso] [int] NULL,
	[id_impuesto_general] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Impuesto_General_MP_version]  DEFAULT ((0)),
	[solo_impuestos] [int] NOT NULL,
 CONSTRAINT [PK_Impuestos_generales_de_marcas] PRIMARY KEY CLUSTERED 
(
	[id_impuesto_general] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Impuesto_Por_Tipo]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Impuesto_Por_Tipo](
	[id_impuesto] [int] NOT NULL,
	[id_tipo] [int] NULL,
	[id_tipo_aplicacion] [int] NULL,
	[id_base_de_calculo] [int] NULL,
	[alicuota] [decimal](12, 2) NULL,
	[minimo_no_imponible] [decimal](12, 2) NULL,
	[flag_estado] [bit] NOT NULL CONSTRAINT [DF_Impuesto_Por_Tipo_flag_estado]  DEFAULT ((1)),
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Impuesto_Por_Tipo_version]  DEFAULT ((0)),
	[id_impuesto_tipo] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[fecha_vigencia_inicio] [datetime] NOT NULL,
	[fecha_vigencia_fin] [datetime] NULL,
 CONSTRAINT [PK_Impuesto_Por_Tipo] PRIMARY KEY CLUSTERED 
(
	[id_impuesto_tipo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Impuesto_Por_Transaccion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Impuesto_Por_Transaccion](
	[id_impuesto_por_transaccion] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_transaccion] [char](36) NOT NULL,
	[id_cargo] [int] NULL,
	[id_impuesto] [int] NOT NULL,
	[monto_calculado] [decimal](12, 2) NULL,
	[alicuota] [decimal](12, 2) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
 CONSTRAINT [PK_Impuesto_Por_Transaccion] PRIMARY KEY CLUSTERED 
(
	[id_impuesto_por_transaccion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Inconsistencia_En_Transaccion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Inconsistencia_En_Transaccion](
	[id_inconsistencia] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[fecha_de_verificacion] [datetime] NOT NULL,
	[id_log_proceso] [int] NOT NULL,
	[id_transaccion] [varchar](36) NOT NULL,
	[campo] [varchar](100) NOT NULL,
	[valor_en_operations] [varchar](512) NULL,
	[valor_en_transactions] [varchar](512) NULL,
 CONSTRAINT [PK_Inconsistencia_En_Transaccion] PRIMARY KEY CLUSTERED 
(
	[id_inconsistencia] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Informacion_Bancaria_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Informacion_Bancaria_Cuenta](
	[id_informacion_bancaria] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[cbu_cuenta_banco] [varchar](22) NOT NULL,
	[numero_cuenta_banco] [varchar](19) NULL,
	[fiid_banco] [varchar](4) NULL,
	[fiidOrigenLink] [varchar](4) NULL,
	[nombre_banco] [varchar](50) NULL,
	[nombre_titular] [varchar](100) NULL,
	[cuit] [varchar](11) NOT NULL,
	[resultado_validacion] [varchar](2) NULL,
	[flag_default] [bit] NOT NULL CONSTRAINT [DF_IBC_flag_default]  DEFAULT ((0)),
	[flag_vigente] [bit] NOT NULL CONSTRAINT [DF_IBC_flag_vigente]  DEFAULT ((0)),
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](100) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](100) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Informacion_Bancaria_Cuenta_version]  DEFAULT ((0)),
	[id_tipo_cuenta_banco] [int] NOT NULL,
	[id_moneda_cuenta_banco] [int] NOT NULL,
	[id_tipo_cashout] [int] NULL,
	[flag_preenrolado] [bit] NOT NULL DEFAULT ((0)),
	[id_estado_informacion_bancaria] [int] NULL,
	[id_tipo_cashout_solicitado] [int] NULL,
	[id_motivo_estado] [int] NULL,
	[id_canal] [int] NULL,
	[fecha_inicio_pendiente] [datetime] NULL,
 CONSTRAINT [PK_Informacion_Bancaria_Cue] PRIMARY KEY CLUSTERED 
(
	[id_informacion_bancaria] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Item_Facturacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Item_Facturacion](
	[id_item_facturacion] [int] NOT NULL,
	[id_log_facturacion] [int] NOT NULL,
	[id_ciclo_facturacion] [int] NOT NULL,
	[tipo] [char](3) NOT NULL,
	[concepto] [char](3) NOT NULL,
	[subconcepto] [char](3) NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[anio] [int] NOT NULL,
	[mes] [int] NOT NULL,
	[suma_cargos] [decimal](18, 2) NOT NULL,
	[suma_impuestos] [decimal](18, 2) NOT NULL,
	[vuelta_facturacion] [varchar](15) NOT NULL CONSTRAINT [DF_Item_Facturacion_vuelta_facturacion]  DEFAULT ('Pendiente'),
	[id_log_vuelta_facturacion] [int] NULL,
	[identificador_carga_dwh] [int] NULL,
	[impuestos_reales] [decimal](18, 2) NULL,
	[tipo_comprobante] [char](1) NULL,
	[nro_comprobante] [int] NULL,
	[fecha_comprobante] [date] NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Item_Facturacion_version]  DEFAULT ((0)),
	[cuenta_aurus] [int] NULL,
	[punto_venta] [char](1) NULL,
	[suma_cargos_aurus] [decimal](18, 2) NULL,
	[fecha_desde_proceso] [datetime] NULL,
	[fecha_hasta_proceso] [datetime] NULL,
	[letra_comprobante] [char](1) NULL,
	[fecha_carga_dw] [datetime] NULL,
 CONSTRAINT [PK_Item_Facturacion] PRIMARY KEY CLUSTERED 
(
	[id_item_facturacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Item_Facturacion_tmp]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Item_Facturacion_tmp](
	[I] [int] NOT NULL,
	[id_item_facturacion] [int] NULL,
	[id_cuenta] [int] NULL,
	[cuenta_aurus] [int] NULL,
	[suma_cargos] [decimal](18, 2) NULL,
	[suma_impuestos] [decimal](18, 2) NULL,
	[diferencia_ajuste] [decimal](18, 2) NULL,
	[vuelta_facturacion] [varchar](15) NULL,
	[id_log_vuelta_facturacion] [int] NULL,
	[identificador_carga_dwh] [int] NULL,
	[impuestos_reales] [decimal](18, 2) NULL,
	[tipo_comprobante] [char](1) NULL,
	[nro_comprobante] [int] NULL,
	[fecha_comprobante] [date] NULL,
	[mascara] [char](1) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[letra_comprobante] [char](1) NULL,
 CONSTRAINT [PK_Item_Facturacion_tmp] PRIMARY KEY CLUSTERED 
(
	[I] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Limite]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [dbo].[Limite](
	[id_limite] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_tipo_limite] [int] NOT NULL,
	[id_tipo_aplicacion_limite] [int] NOT NULL,
	[id_tipo_condicion_IVA] [int] NULL,
	[id_tipo_cuenta] [int] NULL,
	[id_rubro] [int] NULL,
	[id_cuenta] [int] NULL,
	[trxs_diario] [int] NULL,
	[trxs_mensual] [int] NULL,
	[trxs_semestral] [int] NULL,
	[importe_operacion] [decimal](12, 2) NULL,
	[importe_diario] [decimal](12, 2) NULL,
	[importe_mensual] [decimal](12, 2) NULL,
	[importe_semestral] [decimal](12, 2) NULL,
	[id_tipo_accion_limite] [int] NOT NULL,
	[flag_permite_baja] [bit] NOT NULL CONSTRAINT [DF_Limite_flag_permi]  DEFAULT ((1)),
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Limite_version]  DEFAULT ((0)),
	[grupo_limite] [int] NULL,
	[id_tipo_identificacion] [int] NULL
) ON [PRIMARY]
SET ANSI_PADDING ON
ALTER TABLE [dbo].[Limite] ADD [numero_identificacion] [varchar](20) NULL
ALTER TABLE [dbo].[Limite] ADD [sexo] [varchar](1) NULL
ALTER TABLE [dbo].[Limite] ADD [id_tipo_medio_pago] [int] NULL
ALTER TABLE [dbo].[Limite] ADD [id_banco] [int] NULL
ALTER TABLE [dbo].[Limite] ADD [id_nivel_riesgo_mp] [int] NULL
 CONSTRAINT [PK_Limite] PRIMARY KEY CLUSTERED 
(
	[id_limite] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Liquidacion_Tmp]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Liquidacion_Tmp](
	[I] [int] NOT NULL,
	[Id] [char](36) NOT NULL,
	[CreateTimestamp] [datetime] NULL,
	[LocationIdentification] [int] NULL,
	[ProductIdentification] [int] NULL,
	[OperationName] [varchar](128) NULL,
	[Amount] [decimal](12, 2) NULL,
	[FeeAmount] [decimal](12, 2) NULL,
	[TaxAmount] [decimal](12, 2) NULL,
	[CashoutTimestamp] [datetime] NULL,
	[FilingDeadline] [datetime] NULL,
	[PaymentTimestamp] [datetime] NULL,
	[FacilitiesPayments] [int] NULL,
	[LiquidationStatus] [int] NOT NULL,
	[LiquidationTimestamp] [datetime] NULL,
	[PromotionIdentification] [int] NULL,
	[ButtonCode] [varchar](20) NULL,
	[Flag_Ok] [int] NULL,
	[TransactionStatus] [varchar](20) NULL,
 CONSTRAINT [PK_Liquidacion_Tmp] PRIMARY KEY CLUSTERED 
(
	[I] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Lista_Negra_CBU]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Lista_Negra_CBU](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[cbu] [varchar](22) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Lista_Negra_CBU_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Lista_Negra_CBU] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Lista_Negra_Clave]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Lista_Negra_Clave](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[clave] [varchar](50) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
 CONSTRAINT [PK_Lista_Negra_Clave] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Lista_Negra_CUIT]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Lista_Negra_CUIT](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[CUIT] [varchar](30) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Lista_Negra_CUIT_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Lista_Negra_CUIT] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Lista_Negra_Domicilio]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Lista_Negra_Domicilio](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[calle] [varchar](50) NULL,
	[numero] [int] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Lista_Negra_Domicilio_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Lista_Negra_Domicilio] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Lista_Negra_Identificacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Lista_Negra_Identificacion](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_tipo_identificacion] [int] NULL,
	[numero_identificacion] [varchar](30) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Lista_Negra_Identificacion_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Lista_Negra_Identificacion] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Lista_Negra_Mail]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Lista_Negra_Mail](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[mail] [varchar](255) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Lista_Negra_Mail_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Lista_Negra_Mail] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Lista_Negra_Telefono]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Lista_Negra_Telefono](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[telefono] [varchar](10) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
 CONSTRAINT [PK_Lista_Negra_Telefono] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Localidad]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Localidad](
	[id_localidad] [int] NOT NULL,
	[nombre] [varchar](50) NOT NULL,
	[id_provincia] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Localidad_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Localidad] PRIMARY KEY CLUSTERED 
(
	[id_localidad] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Log_Control_Liquidacion_Disponible]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Log_Control_Liquidacion_Disponible](
	[id_log_control] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_log_proceso] [int] NULL,
	[id_transaccion] [char](36) NULL,
	[importe] [decimal](12, 2) NULL,
 CONSTRAINT [PK_Log_Control_Liquidacion_Disponible] PRIMARY KEY CLUSTERED 
(
	[id_log_control] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Log_Movimiento_Cuenta_Virtual]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Log_Movimiento_Cuenta_Virtual](
	[id_log_movimiento] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_tipo_movimiento] [int] NOT NULL,
	[id_tipo_origen_movimiento] [int] NOT NULL,
	[id_log_proceso] [int] NULL,
	[id_cuenta] [int] NOT NULL,
	[monto_disponible] [decimal](12, 2) NULL CONSTRAINT [DF_Log_Movimiento_Cuenta_Vi_monto]  DEFAULT ((0)),
	[disponible_anterior] [decimal](12, 2) NULL CONSTRAINT [DF_Log_Movimiento_Cuenta_Vi_disponible]  DEFAULT ((0)),
	[disponible_actual] [decimal](12, 2) NULL CONSTRAINT [DF_Log_Movim_disponible_actual]  DEFAULT ((0)),
	[saldo_cuenta_anterior] [decimal](12, 2) NULL CONSTRAINT [DF_Log_Movimiento_Cuenta_Vi_saldo_cuen]  DEFAULT ((0)),
	[saldo_cuenta_actual] [decimal](12, 2) NULL CONSTRAINT [DF_Log_Movim_saldo_saldo_cuenta_actual]  DEFAULT ((0)),
	[saldo_revision_anterior] [decimal](12, 2) NULL CONSTRAINT [DF_Log_Movimiento_Cuenta_Vi_saldo_revi]  DEFAULT ((0)),
	[saldo_revision_actual] [decimal](12, 2) NULL CONSTRAINT [DF_Log_Movim_saldo_revision_actual]  DEFAULT ((0)),
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Log_Movimiento_Cuenta_Virtual_version]  DEFAULT ((0)),
	[monto_saldo_cuenta] [decimal](12, 2) NULL CONSTRAINT [DF_Log_Movimiento_Cuenta_Virtual_monto_saldo_cuenta]  DEFAULT ((0)),
	[monto_revision] [decimal](12, 2) NULL CONSTRAINT [DF_Log_Movimiento_Cuenta_Virtual_monto_revision]  DEFAULT ((0)),
	[id_canal] [int] NULL,
 CONSTRAINT [PK_Log_Movimiento_Cuenta_Vi] PRIMARY KEY CLUSTERED 
(
	[id_log_movimiento] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Log_Paso_Proceso]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Log_Paso_Proceso](
	[id_log_paso] [int] NOT NULL,
	[id_log_proceso] [int] NULL,
	[id_paso_proceso] [int] NULL,
	[fecha_inicio_ejecucion] [datetime] NULL,
	[fecha_fin_ejecucion] [datetime] NULL,
	[descripcion] [varchar](25) NULL,
	[archivo_entrada] [varchar](256) NULL,
	[archivo_salida] [varchar](256) NULL,
	[resultado_proceso] [bit] NULL,
	[motivo_rechazo] [varchar](100) NULL,
	[registros_procesados] [int] NULL,
	[importe_procesados] [decimal](12, 2) NULL,
	[registros_aceptados] [int] NULL,
	[importe_aceptados] [decimal](12, 2) NULL,
	[registros_rechazados] [int] NULL,
	[importe_rechazados] [decimal](12, 2) NULL,
	[registros_salida] [int] NULL,
	[importe_salida] [decimal](12, 2) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Log_Paso_Proceso_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Log_Paso_Proceso] PRIMARY KEY CLUSTERED 
(
	[id_log_paso] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Log_Proceso]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Log_Proceso](
	[id_log_proceso] [int] NOT NULL,
	[id_proceso] [int] NULL,
	[fecha_inicio_ejecucion] [datetime] NULL,
	[fecha_fin_ejecucion] [datetime] NULL,
	[fecha_desde_proceso] [datetime] NULL,
	[fecha_hasta_proceso] [datetime] NULL,
	[registros_afectados] [int] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Log_Proceso_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Log_Proceso] PRIMARY KEY CLUSTERED 
(
	[id_log_proceso] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Log_Registracion_CBU]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Log_Registracion_CBU](
	[id_log] [int] NOT NULL,
	[id_informacion_bancaria_cuenta] [int] NOT NULL,
	[resultado_validacion] [varchar](20) NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](100) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](100) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL DEFAULT ('0')
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Log_Validacion_Link]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Log_Validacion_Link](
	[id_log_validacion_link] [int] NOT NULL,
	[numero_tarjeta] [varchar](20) NOT NULL,
	[codigo_banco] [varchar](4) NOT NULL,
	[tipo_documento] [varchar](3) NOT NULL,
	[numero_documento] [varchar](20) NOT NULL,
	[resultado_validacion] [varchar](2) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[id_log_validacion_link] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Mail_Grupo_Notificacion_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Mail_Grupo_Notificacion_Cuenta](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[id_grupo_notificacion] [int] NOT NULL,
	[mail_destino] [varchar](50) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Mail_Grupo_Notificacion_Cuenta_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Mail_Grupo_Notificacion_] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Mail_Notificacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Mail_Notificacion](
	[id] [int] NOT NULL,
	[id_notificacion] [int] NOT NULL,
	[mail_destino] [varchar](50) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Mail_Notificacion_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Mail_Notificacion] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Medio_De_Pago]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Medio_De_Pago](
	[id_medio_pago] [int] NOT NULL,
	[id_tipo_medio_pago] [int] NOT NULL,
	[nro_comercio] [varchar](50) NULL,
	[flag_habilitado] [int] NULL,
	[flag_control_vencimiento] [bit] NULL,
	[flag_codigo_seguridad] [bit] NULL,
	[longitud_codigo_seguridad] [int] NULL,
	[flag_ultimos_4digitos] [bit] NULL,
	[flag_opera_cuotas] [bit] NULL,
	[flag_opera_planes] [bit] NULL,
	[cuota_minima_plan] [int] NULL,
	[flag_opera_dolares] [bit] NOT NULL,
	[flag_permite_preautorizacion] [bit] NOT NULL,
	[flag_control_monto_tx] [bit] NULL,
	[monto_minimo_tx] [decimal](12, 2) NULL,
	[monto_maximo_tx] [decimal](12, 2) NULL,
	[plazo_pago_marca] [int] NOT NULL,
	[margen_espera_pago_marca] [int] NOT NULL,
	[plazo_resolucion_disputa_marca] [int] NOT NULL,
	[plazo_resolucion_disputa_cuenta] [int] NOT NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL
) ON [PRIMARY]
SET ANSI_PADDING OFF
ALTER TABLE [dbo].[Medio_De_Pago] ADD [codigo] [varchar](20) NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [nombre] [varchar](50) NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [id_mp_decidir] [int] NOT NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [fecha_modificacion] [datetime] NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [flag_opera_con_banco] [bit] NOT NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [flag_opera_datos_adicionales] [bit] NOT NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [longitud_max_tarjeta] [int] NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [longitud_min_tarjeta] [int] NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [plazo_primer_vto] [int] NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [plazo_segundo_vto] [int] NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [porcentaje_recargo_vto] [decimal](12, 2) NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [tope_primer_vto] [int] NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [usuario_modificacion] [varchar](20) NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [version] [int] NOT NULL CONSTRAINT [DF_Medio_De_Pago_version]  DEFAULT ((0))
ALTER TABLE [dbo].[Medio_De_Pago] ADD [flag_informa_rubro] [bit] NULL CONSTRAINT [DF_Medio_De_Pago__flag_inf_rubro]  DEFAULT ((0))
ALTER TABLE [dbo].[Medio_De_Pago] ADD [plazo_devolucion] [int] NULL CONSTRAINT [DF_Medio_De_Pago__plazo_devolucion]  DEFAULT (NULL)
ALTER TABLE [dbo].[Medio_De_Pago] ADD [flag_permite_anulacion] [bit] NOT NULL CONSTRAINT [DF_Medio_De_Pago__flag_permite_anulacion]  DEFAULT ((0))
ALTER TABLE [dbo].[Medio_De_Pago] ADD [flag_permite_devolucion] [bit] NOT NULL CONSTRAINT [DF_Medio_De_Pago__flag_permite_devolucion]  DEFAULT ((0))
ALTER TABLE [dbo].[Medio_De_Pago] ADD [flag_permite_segundo_vto] [bit] NULL CONSTRAINT [DF_Medio_De_Pago__flag_permite_segundo_vto]  DEFAULT ((0))
SET ANSI_PADDING ON
ALTER TABLE [dbo].[Medio_De_Pago] ADD [logo] [varchar](256) NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [tipo_codigo_barra] [varchar](50) NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [url_mp] [varchar](256) NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [flag_permite_devolucion_sin_cvv] [bit] NOT NULL DEFAULT ((0))
ALTER TABLE [dbo].[Medio_De_Pago] ADD [flag_permite_contracargo] [bit] NOT NULL DEFAULT ((0))
ALTER TABLE [dbo].[Medio_De_Pago] ADD [flag_permite_transaccion_sin_cvv] [bit] NOT NULL DEFAULT ((0))
ALTER TABLE [dbo].[Medio_De_Pago] ADD [orden] [int] NULL DEFAULT ((0))
ALTER TABLE [dbo].[Medio_De_Pago] ADD [id_resolutor] [int] NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [cant_maxima_cuotas_mp] [int] NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [cant_maxima_cuotas_boton] [int] NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [texto_codigo_seguridad] [varchar](255) NULL
ALTER TABLE [dbo].[Medio_De_Pago] ADD [imagen_codigo_seguridad] [varchar](50) NULL
 CONSTRAINT [PK_Medio_De_Pago] PRIMARY KEY CLUSTERED 
(
	[id_medio_pago] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Medio_Pago_Banco]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Medio_Pago_Banco](
	[id_medio_pago_banco] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_medio_pago] [int] NOT NULL,
	[id_banco] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Medio_Pago_Banco_version]  DEFAULT ((0)),
	[red_opera] [varchar](20) NULL,
 CONSTRAINT [PK_Medio_Pago_Banco] PRIMARY KEY CLUSTERED 
(
	[id_medio_pago_banco] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY],
 CONSTRAINT [UQ_Medio_Pago_Banco] UNIQUE NONCLUSTERED 
(
	[id_medio_pago] ASC,
	[id_banco] ASC,
	[fecha_baja] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Medio_Pago_Boton]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [dbo].[Medio_Pago_Boton](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_medio_pago] [int] NOT NULL,
	[id_boton] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Medio_Pago_Boton_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Medio_Pago_Boton] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Medio_Pago_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Medio_Pago_Cuenta](
	[id_medio_pago_cuenta] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[id_banco] [int] NOT NULL,
	[encript_numero_tarjeta] [varchar](500) NOT NULL,
	[mascara_numero_tarjeta] [varchar](20) NOT NULL,
	[hash_numero_tarjeta] [varchar](256) NOT NULL,
	[fecha_vencimiento] [varchar](6) NOT NULL,
	[id_estado_medio_pago] [int] NOT NULL,
	[flag_favorito] [bit] NOT NULL CONSTRAINT [DF_Medio_Pago_Cuenta_flag_favotrito]  DEFAULT ((0)),
	[monto_a_validar] [decimal](12, 2) NULL,
	[id_nivel_riesgo] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Medio_Pago_Cuenta_version]  DEFAULT ((0)),
	[id_medio_pago] [int] NOT NULL,
	[id_tipo_medio_pago] [int] NULL,
	[medio_notificado] [int] NOT NULL DEFAULT ((0)),
	[id_transaccion_validacion] [varchar](36) NULL,
	[flag_montoAcreditado] [bit] NULL,
 CONSTRAINT [PK_id_medio_pago_cuenta] PRIMARY KEY CLUSTERED 
(
	[id_medio_pago_cuenta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Medio_Pago_Transaccion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Medio_Pago_Transaccion](
	[id_medio_pago_transaccion] [int] IDENTITY(1,1) NOT NULL,
	[id_medio_pago] [int] NULL,
	[id_transaccion] [char](36) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](30) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](30) NULL,
 CONSTRAINT [PK_Medio_Pago_Transaccion] PRIMARY KEY CLUSTERED 
(
	[id_medio_pago_transaccion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [Unique_Medio_Pago_Por_Transaccion] UNIQUE NONCLUSTERED 
(
	[id_medio_pago] ASC,
	[id_transaccion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Mensaje]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Mensaje](
	[id_mensaje] [int] NOT NULL,
	[codigo_mensaje] [int] NOT NULL,
	[evento] [varchar](100) NULL,
	[mensaje] [varchar](max) NULL,
	[formato] [varchar](256) NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Mensaje_version]  DEFAULT ((0)),
	[motivo_rechazo] [varchar](256) NULL,
	[flag_reintento_tx] [bit] NULL,
 CONSTRAINT [PK_Mensaje] PRIMARY KEY CLUSTERED 
(
	[id_mensaje] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Moneda]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [dbo].[Moneda](
	[id_moneda] [int] NOT NULL,
	[codigo] [varchar](5) NULL,
	[nombre] [varchar](50) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Moneda_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Moneda] PRIMARY KEY CLUSTERED 
(
	[id_moneda] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Moneda_Medio_Pago]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [dbo].[Moneda_Medio_Pago](
	[id_moneda_mp] [int] NOT NULL,
	[id_medio_pago] [int] NULL,
	[id_moneda] [int] NULL,
	[moneda_mp_conciliacion] [varchar](5) NULL,
	[moneda_mp_autorizacion] [varchar](5) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Moneda_Medio_Pago_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Moneda_Medio_Pago] PRIMARY KEY CLUSTERED 
(
	[id_moneda_mp] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Motivo]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Motivo](
	[id_motivo] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_grupo_motivo] [int] NOT NULL,
	[codigo] [varchar](20) NOT NULL,
	[nombre] [varchar](50) NOT NULL,
	[descripcion] [varchar](200) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL DEFAULT (NULL),
	[usuario_modificacion] [varchar](20) NULL DEFAULT (NULL),
	[fecha_baja] [datetime] NULL DEFAULT (NULL),
	[usuario_baja] [varchar](20) NULL DEFAULT (NULL),
	[version] [int] NOT NULL DEFAULT ((0)),
PRIMARY KEY CLUSTERED 
(
	[id_motivo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Motivo_Ajuste]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Motivo_Ajuste](
	[id_motivo_ajuste] [int] NOT NULL,
	[codigo] [varchar](15) NOT NULL,
	[descripcion] [varchar](max) NOT NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Motivo_Ajuste_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Motivo_Ajuste] PRIMARY KEY CLUSTERED 
(
	[id_motivo_ajuste] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Motivo_Estado]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Motivo_Estado](
	[id_motivo_estado] [int] NOT NULL,
	[id_estado] [int] NULL,
	[codigo] [varchar](20) NOT NULL,
	[descripcion] [varchar](100) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Motivo_Estado_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Motivo_Estado] PRIMARY KEY CLUSTERED 
(
	[id_motivo_estado] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Movimiento_Presentado_Decidir]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Movimiento_Presentado_Decidir](
	[importe] [decimal](12, 2) NULL,
	[signo_importe] [char](1) NULL,
	[moneda] [int] NULL,
	[cantidad_cuotas] [int] NULL,
	[nro_tarjeta] [nvarchar](50) NULL,
	[codigo_barra] [varchar](128) NULL,
	[fecha_movimiento] [datetime] NULL,
	[nro_autorizacion] [varchar](8) NULL,
	[nro_cupon] [int] NULL,
	[nro_agrupador] [varchar](50) NULL,
	[id_log_paso] [int] NULL,
	[id_medio_pago] [int] NULL,
	[id_movimiento_decidir] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_codigo_operacion] [int] NULL,
	[fecha_presentacion] [datetime] NULL,
	[nro_lote] [varchar](15) NULL,
	[validacion_resultado_mov] [varchar](250) NULL,
	[id_site] [int] NULL,
	[id_transaccion] [varchar](64) NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [bit] NOT NULL,
 CONSTRAINT [PK_Movimiento_Presentado_Decidir] PRIMARY KEY CLUSTERED 
(
	[id_movimiento_decidir] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Movimiento_Presentado_MP]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Movimiento_Presentado_MP](
	[importe] [decimal](12, 2) NULL,
	[signo_importe] [char](1) NULL,
	[moneda] [int] NULL,
	[cantidad_cuotas] [int] NULL,
	[nro_tarjeta] [nvarchar](50) NULL,
	[codigo_barra] [varchar](128) NULL,
	[fecha_movimiento] [datetime] NULL,
	[nro_autorizacion] [varchar](8) NULL,
	[nro_cupon] [int] NULL,
	[nro_agrupador_boton] [varchar](50) NULL,
	[cargos_marca_por_movimiento] [decimal](12, 2) NULL,
	[signo_cargos_marca_por_movimiento] [char](1) NULL,
	[id_log_paso] [int] NULL,
	[id_medio_pago] [int] NULL,
	[id_movimiento_mp] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_codigo_operacion] [int] NULL,
	[fecha_pago] [datetime] NULL,
	[nro_lote] [varchar](15) NULL,
	[hash_nro_tarjeta] [varchar](80) NULL,
	[validacion_resultado_mov] [varchar](250) NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [bit] NOT NULL CONSTRAINT [DF_MPMP_version]  DEFAULT ((0)),
	[mask_nro_tarjeta] [varchar](20) NULL,
 CONSTRAINT [PK_Movimiento_Presentado_MP] PRIMARY KEY CLUSTERED 
(
	[id_movimiento_mp] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Movimientos_a_distribuir]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Movimientos_a_distribuir](
	[id_transaccion] [char](36) NULL
) ON [PRIMARY]
SET ANSI_PADDING OFF
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [tipo] [varchar](1) NULL CONSTRAINT [DF_Movimientos_a_distribuir_tipo]  DEFAULT ('M')
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [id_medio_pago] [int] NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [id_cuenta] [int] NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [BCRA_cuenta] [int] NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [BCRA_emisor_tarjeta] [int] NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [signo_importe] [char](1) NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [importe] [decimal](12, 2) NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [signo_cargo_marca] [char](1) NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [cargo_marca] [decimal](12, 2) NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [signo_cargo_boton] [char](1) NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [cargo_boton] [decimal](12, 2) NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [signo_impuesto_boton] [char](1) NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [impuesto_boton] [decimal](12, 2) NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [fecha_liberacion_cashout] [datetime] NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [id_log_paso] [int] NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [flag_esperando_impuestos_generales_de_marca] [bit] NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [fecha_alta] [datetime] NOT NULL
SET ANSI_PADDING ON
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [usuario_alta] [varchar](20) NOT NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [fecha_modificacion] [datetime] NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [usuario_modificacion] [varchar](20) NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [fecha_baja] [datetime] NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [usuario_baja] [varchar](20) NULL
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [version] [int] NOT NULL CONSTRAINT [DF_MAD_version]  DEFAULT ((0))
ALTER TABLE [dbo].[Movimientos_a_distribuir] ADD [id_movimiento_mp] [int] NULL

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Nacionalidad]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Nacionalidad](
	[id_nacionalidad] [int] NOT NULL,
	[nombre] [varchar](50) NOT NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Nacionalidad_version]  DEFAULT ((0)),
	[codigo] [varchar](20) NOT NULL,
	[codigo_aurus] [int] NOT NULL,
 CONSTRAINT [PK_Nacionalidad] PRIMARY KEY CLUSTERED 
(
	[id_nacionalidad] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Nivel_Riesgo_MP]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Nivel_Riesgo_MP](
	[id_nivel_riesgo] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[codigo] [varchar](3) NOT NULL,
	[descripcion_corta] [varchar](50) NOT NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL DEFAULT ((0)),
PRIMARY KEY CLUSTERED 
(
	[id_nivel_riesgo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Notificacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Notificacion](
	[id_notificacion] [int] NOT NULL,
	[id_grupo_notificacion] [int] NULL,
	[nombre] [varchar](100) NOT NULL,
	[descripcion] [varchar](100) NULL,
	[destino] [varchar](20) NULL,
	[asunto] [varchar](100) NULL,
	[template] [image] NULL,
	[flag_activa] [bit] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Notificacion_version]  DEFAULT ((0)),
	[mail_origen] [varchar](50) NOT NULL,
	[orden] [int] NULL,
 CONSTRAINT [PK_Notificacion] PRIMARY KEY CLUSTERED 
(
	[id_notificacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Notificacion_Enviada]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Notificacion_Enviada](
	[id_notificacion_enviada] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_notificacion] [int] NOT NULL,
	[id_cuenta] [int] NULL,
	[fecha_envio] [datetime] NOT NULL,
	[mail_destino] [varchar](50) NOT NULL,
	[mensaje] [varchar](max) NOT NULL,
	[hash] [varchar](512) NULL,
	[flag_leido] [bit] NOT NULL CONSTRAINT [DF_Notificacion_Enviada_flag_leido]  DEFAULT ((0)),
	[operacion_asociada] [varchar](100) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Notificacion_Enviada_version]  DEFAULT ((0)),
	[flag_enviado] [bit] NULL,
 CONSTRAINT [PK_Notificacion_Enviada] PRIMARY KEY CLUSTERED 
(
	[id_notificacion_enviada] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Notificacion_Parametro]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Notificacion_Parametro](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_notificacion] [int] NOT NULL,
	[nombre_parametro] [varchar](50) NOT NULL,
	[valor_parametro] [varchar](200) NULL,
 CONSTRAINT [PK_Notificacion_Parametro] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Notificacion_Recibida]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Notificacion_Recibida](
	[id_notificacion_recibida] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_notificacion] [int] NOT NULL,
	[id_cuenta] [int] NULL,
	[nombre] [varchar](50) NOT NULL,
	[eMail] [varchar](50) NOT NULL,
	[fecha_recepcion] [datetime] NOT NULL,
	[mensaje] [varchar](max) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Notificacion_Recibida_version]  DEFAULT ((0)),
	[puesto] [varchar](50) NULL,
	[empresa] [varchar](50) NULL,
	[telefono_contacto] [varchar](10) NULL,
 CONSTRAINT [PK_Notificacion_Recibida] PRIMARY KEY CLUSTERED 
(
	[id_notificacion_recibida] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Operador_Celular]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Operador_Celular](
	[id_operador_celular] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[codigo] [varchar](20) NOT NULL,
	[descripcion] [varchar](30) NOT NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Operador_Celular_version]  DEFAULT ((0)),
 CONSTRAINT [PK_id_operador_celular] PRIMARY KEY CLUSTERED 
(
	[id_operador_celular] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Operatoria_MP_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Operatoria_MP_Cuenta](
	[id_operatoria_mp_cuenta] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[id_medio_pago] [int] NOT NULL,
	[cant_maxima_cuotas] [int] NOT NULL,
	[nro_comercio_billetera] [varchar](50) NULL,
	[nro_comercio_boton] [varchar](50) NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Operatoria_MP_Cuenta_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Operatoria_MP_Cuenta] PRIMARY KEY CLUSTERED 
(
	[id_operatoria_mp_cuenta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Padron_Alto_Riesgo_Fiscal]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Padron_Alto_Riesgo_Fiscal](
	[id] [int] NOT NULL,
	[numero_CUIT] [varchar](11) NOT NULL,
 CONSTRAINT [PK_Padron_Alto_Riesgo_Fisca] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Padron_Grandes_Contribuyentes]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Padron_Grandes_Contribuyentes](
	[id] [int] NOT NULL,
	[numero_CUIT] [varchar](11) NOT NULL,
 CONSTRAINT [PK_Padron_Grandes_Contribuy] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Padron_Mensual_Rentas]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Padron_Mensual_Rentas](
	[id] [int] NOT NULL,
	[numero_CUIT] [varchar](11) NOT NULL,
	[alicuota] [decimal](12, 2) NOT NULL,
 CONSTRAINT [PK_Padron_Mensual_Rentas] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Padron_Regimen_Simplificado]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Padron_Regimen_Simplificado](
	[id] [int] NOT NULL,
	[numero_CUIT] [varchar](11) NOT NULL,
 CONSTRAINT [PK_Padron_Regimen_Simplific] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Parametro]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Parametro](
	[id_parametro] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_tipo_parametro] [int] NULL,
	[codigo] [varchar](20) NULL,
	[nombre] [varchar](100) NULL,
	[valor] [varchar](256) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Parametro_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Parametro] PRIMARY KEY CLUSTERED 
(
	[id_parametro] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Parametro_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Parametro_Cuenta](
	[id_parametro_cuenta] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[flag_reporte_comercio] [bit] NOT NULL CONSTRAINT [DF_Parametro_Cuenta_flag_reporte_c]  DEFAULT ((0)),
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Parametro_Cuenta_version]  DEFAULT ((0)),
	[api_key] [varchar](64) NULL,
	[api_key_pruebas] [varchar](64) NULL,
	[id_cuenta_pruebas] [int] NULL,
	[flag_excepcion_cybersource] [bit] NULL CONSTRAINT [DF_Parametro_Cuenta_flag_excepcion_cybersource]  DEFAULT ((0)),
	[tope_cuotas_credito] [int] NULL,
 CONSTRAINT [PK_Parametro_Cuenta] PRIMARY KEY CLUSTERED 
(
	[id_parametro_cuenta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Paso_Proceso]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Paso_Proceso](
	[id_paso_proceso] [int] NOT NULL,
	[id_proceso] [int] NULL,
	[paso] [int] NOT NULL,
	[nombre] [varchar](80) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Paso_Proceso_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Paso_Proceso] PRIMARY KEY CLUSTERED 
(
	[id_paso_proceso] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Plan]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Plan](
	[id_plan] [int] NOT NULL,
	[id_medio_pago] [int] NULL,
	[nombre] [varchar](20) NULL,
	[transmite_valor] [int] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
 CONSTRAINT [PK_Plan] PRIMARY KEY CLUSTERED 
(
	[id_plan] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Plazo_Liberacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [dbo].[Plazo_Liberacion](
	[id_plazo_liberacion] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_tipo_medio_pago] [int] NOT NULL,
	[id_tipo_cuenta] [int] NULL,
	[id_rubro] [int] NULL,
	[id_cuenta] [int] NULL,
	[plazo_liberacion] [int] NOT NULL,
	[plazo_liberacion_cuotas] [int] NULL,
	[flag_permite_baja] [bit] NOT NULL CONSTRAINT [DF_Plazo_Liberacion_flag_permi]  DEFAULT ((1)),
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Plazo_Liberacion_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Plazo_Liberacion] PRIMARY KEY CLUSTERED 
(
	[id_plazo_liberacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[PreConciliacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[PreConciliacion](
	[id_preconciliacion] [int] NOT NULL,
	[id_transaccion] [char](36) NULL,
	[id_log_paso] [int] NULL,
	[flag_preconciliada] [bit] NOT NULL,
	[id_preconciliacion_manual] [int] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
	[id_movimiento_decidir] [int] NULL,
 CONSTRAINT [PK_PreConciliacion] PRIMARY KEY CLUSTERED 
(
	[id_preconciliacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[PreConciliacion_Manual]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[PreConciliacion_Manual](
	[id_preconciliacion_manual] [int] NOT NULL,
	[id_transaccion] [char](36) NULL,
	[importe] [decimal](12, 2) NULL,
	[moneda] [int] NULL,
	[cantidad_cuotas] [int] NULL,
	[nro_tarjeta] [varchar](50) NULL,
	[codigo_barra] [varchar](128) NULL,
	[fecha_movimiento] [datetime] NULL,
	[nro_autorizacion] [varchar](50) NULL,
	[nro_cupon] [varchar](50) NULL,
	[nro_agrupador_boton] [varchar](50) NULL,
	[flag_preconciliado_manual] [bit] NOT NULL,
	[flag_procesado] [bit] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
	[fecha_presentacion] [datetime] NULL,
	[id_log_paso] [int] NULL,
	[id_movimiento_decidir] [int] NULL,
 CONSTRAINT [PK_PreConciliacion_Manual] PRIMARY KEY CLUSTERED 
(
	[id_preconciliacion_manual] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Pregunta_Seguridad]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Pregunta_Seguridad](
	[id_pregunta_seguridad] [int] NOT NULL,
	[pregunta_seguridad] [varchar](100) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Pregunta_Seguridad_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Pregunta_Seguridad] PRIMARY KEY CLUSTERED 
(
	[id_pregunta_seguridad] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Primera_Vez_Banco_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Primera_Vez_Banco_Cuenta](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[id_banco] [int] NOT NULL,
	[codigo_banco] [varchar](3) NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL DEFAULT ('0'),
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Procesar_Facturacion_tmp]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Procesar_Facturacion_tmp](
	[I] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id] [varchar](36) NULL,
	[LocationIdentification] [int] NULL,
	[LiquidationTimeStamp] [datetime] NULL,
	[LiquidationStatus] [int] NULL,
	[BillingTimeStamp] [datetime] NULL,
	[BillingStatus] [int] NULL,
	[CreateTimeStamp] [datetime] NULL,
	[Amount] [decimal](12, 2) NULL,
	[FeeAmount] [decimal](12, 2) NULL,
	[TaxAmount] [decimal](12, 2) NULL,
	[OperationName] [varchar](128) NULL,
 CONSTRAINT [PK_Procesar_Facturacion_tmp] PRIMARY KEY CLUSTERED 
(
	[I] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Proceso]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Proceso](
	[id_proceso] [int] NOT NULL,
	[nombre] [varchar](50) NOT NULL,
	[id_tipo_frecuencia] [int] NOT NULL,
	[valor_frecuencia] [int] NOT NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Proceso_version]  DEFAULT ((0)),
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
 CONSTRAINT [PK_Proceso] PRIMARY KEY CLUSTERED 
(
	[id_proceso] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Promocion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Promocion](
	[id_promocion] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[nombre] [varchar](50) NOT NULL,
	[descripcion] [varchar](100) NULL,
	[cant_cuotas_desde] [int] NOT NULL,
	[cant_cuotas_hasta] [int] NOT NULL,
	[fecha_inicio_vigencia] [date] NOT NULL,
	[fecha_fin_vigencia] [date] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Promocion_version]  DEFAULT ((0)),
	[id_medio_pago] [int] NULL,
	[id_banco] [int] NULL,
	[id_cuenta] [int] NULL,
	[id_rubro] [int] NULL,
	[flag_aplica_lunes] [bit] NOT NULL CONSTRAINT [DF_Promocion_flag_activa_lunes]  DEFAULT ((0)),
	[flag_aplica_martes] [bit] NOT NULL CONSTRAINT [DF_Promocion_flag_activa_martes]  DEFAULT ((0)),
	[flag_aplica_miercoles] [bit] NOT NULL CONSTRAINT [DF_Promocion_flag_activa_miercoles]  DEFAULT ((0)),
	[flag_aplica_jueves] [bit] NOT NULL CONSTRAINT [DF_Promocion_flag_activa_jueves]  DEFAULT ((0)),
	[flag_aplica_viernes] [bit] NOT NULL CONSTRAINT [DF_Promocion_flag_activa_viernes]  DEFAULT ((0)),
	[flag_aplica_sabado] [bit] NOT NULL CONSTRAINT [DF_Promocion_flag_activa_sabado]  DEFAULT ((0)),
	[flag_aplica_domingo] [bit] NOT NULL CONSTRAINT [DF_Promocion_flag_activa_domingo]  DEFAULT ((0)),
	[bonificacion_cf_comprador] [bit] NOT NULL CONSTRAINT [DF_Promocion_bonificacion_cf_comprador]  DEFAULT ((0)),
	[id_motivo_estado] [int] NULL,
	[id_estado_procesamiento] [int] NOT NULL,
	[id_tipo_aplicacion] [int] NOT NULL,
 CONSTRAINT [PK_Promocion] PRIMARY KEY CLUSTERED 
(
	[id_promocion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Promocion_Medio_Pago]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Promocion_Medio_Pago](
	[id_promocion_mp] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_promocion] [int] NOT NULL,
	[id_medio_pago] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
 CONSTRAINT [PK_Promocion_Medio_Pago] PRIMARY KEY CLUSTERED 
(
	[id_promocion_mp] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Promocion_Medio_Pago_Banco]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Promocion_Medio_Pago_Banco](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_promocion_mp] [int] NOT NULL,
	[id_banco] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
 CONSTRAINT [PK_Promocion_Medio_Pago_Banco] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Provincia]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Provincia](
	[id_provincia] [int] NOT NULL,
	[codigo] [varchar](20) NULL,
	[nombre] [varchar](60) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Provincia_version]  DEFAULT ((0)),
	[codigo_aurus] [char](1) NOT NULL,
 CONSTRAINT [PK_Provincia] PRIMARY KEY CLUSTERED 
(
	[id_provincia] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Rango_BIN]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Rango_BIN](
	[id_rango_bin] [int] NOT NULL,
	[id_medio_pago] [int] NOT NULL,
	[longitud_prefijo] [int] NOT NULL,
	[bin_desde] [varchar](19) NOT NULL,
	[bin_hasta] [varchar](19) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Rango_BIN_version]  DEFAULT ((0)),
	[longitud_busqueda] [int] NULL,
	[flag_bin_local] [bit] NOT NULL DEFAULT ((1)),
	[flag_controla_vencimiento] [bit] NOT NULL DEFAULT ((1)),
 CONSTRAINT [PK_Rango_BIN] PRIMARY KEY CLUSTERED 
(
	[id_rango_bin] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Regla_Bonificacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Regla_Bonificacion](
	[id_regla_bonificacion] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_tasa_mp] [int] NOT NULL,
	[fecha_desde] [date] NOT NULL,
	[fecha_hasta] [date] NULL,
	[id_banco] [int] NULL,
	[id_cuenta] [int] NULL,
	[dia_semana] [varchar](7) NULL,
	[bonificacion_cf_comprador] [bit] NOT NULL CONSTRAINT [DF_Regla_Bonificacion_bonificación_cf_comprador]  DEFAULT ((0)),
	[bonificacion_cf_vendedor] [decimal](5, 2) NULL,
	[id_promocion] [int] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Regla_Bonificacion_version]  DEFAULT ((0)),
	[id_regla_promocion] [int] NULL,
	[id_rubro] [int] NULL,
 CONSTRAINT [PK_Regla_Bonificacion] PRIMARY KEY CLUSTERED 
(
	[id_regla_bonificacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Regla_Operacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [dbo].[Regla_Operacion](
	[id_regla_operacion] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_tipo_cuenta] [int] NULL,
	[id_rubro] [int] NULL,
	[id_cuenta] [int] NULL,
	[id_tipo_regla_operacion] [int] NULL,
	[flag_permite_operacion] [bit] NOT NULL CONSTRAINT [DF_Tipo_Liberacion_flag_permi]  DEFAULT ((0)),
	[flag_permite_baja] [bit] NOT NULL CONSTRAINT [DF_Tipo_Liberacion_flag_baja]  DEFAULT ((1)),
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Regla_Operacion_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Tipo_Liberacion] PRIMARY KEY CLUSTERED 
(
	[id_regla_operacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Regla_Promocion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Regla_Promocion](
	[id_regla_promocion] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_promocion] [int] NOT NULL,
	[cant_cuotas_desde] [int] NOT NULL,
	[cant_cuotas_hasta] [int] NOT NULL,
	[bonificacion_cf_vendedor] [decimal](5, 2) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Regla_Promocion_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Regla_Promocion] PRIMARY KEY CLUSTERED 
(
	[id_regla_promocion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Relacion_Banco_CU]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Relacion_Banco_CU](
	[id_banco_cu] [int] NOT NULL,
	[cod_banco_cu] [varchar](3) NOT NULL,
	[id_tipo_medio_pago] [int] NOT NULL,
	[cod_banco_ext] [varchar](3) NOT NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NULL,
 CONSTRAINT [uc_relacion_banco_cu] UNIQUE NONCLUSTERED 
(
	[id_banco_cu] ASC,
	[id_tipo_medio_pago] ASC,
	[cod_banco_ext] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Resolutor_Transaccion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [dbo].[Resolutor_Transaccion](
	[id_resolutor] [int] NOT NULL,
	[codigo_resolutor] [varchar](20) NOT NULL,
	[descripcion] [varchar](20) NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Resolutor_Transaccion_version]  DEFAULT ((0)),
 CONSTRAINT [PK_id_resolutor] PRIMARY KEY CLUSTERED 
(
	[id_resolutor] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Resumen_Analisis_De_Saldo]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Resumen_Analisis_De_Saldo](
	[id_resumen] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NOT NULL,
	[fecha_de_analisis] [datetime] NOT NULL,
	[cantidad_ventas] [int] NOT NULL,
	[importe_ventas] [decimal](15, 2) NOT NULL,
	[cantidad_devoluciones] [int] NOT NULL,
	[importe_devoluciones] [decimal](15, 2) NOT NULL,
	[cantidad_cashout] [int] NOT NULL,
	[importe_cashout] [decimal](15, 2) NOT NULL,
	[cantidad_ajustes] [int] NOT NULL,
	[importe_ajustes] [decimal](15, 2) NOT NULL,
	[cantidad_contracargos] [int] NOT NULL,
	[importe_contracargos] [decimal](15, 2) NOT NULL,
	[cantidad_total_movimientos] [int] NOT NULL,
	[importe_total_movimientos] [decimal](15, 2) NOT NULL,
	[saldo_en_cuenta] [decimal](15, 2) NOT NULL,
	[diferencia_de_saldo] [decimal](15, 2) NOT NULL,
	[log_movimientos_cuenta_ok] [bit] NOT NULL,
	[flag_generar_detalle] [bit] NOT NULL,
	[detalle_generado_ok] [bit] NULL,
 CONSTRAINT [PK_Resumen_Analisis_De_Saldo] PRIMARY KEY CLUSTERED 
(
	[id_resumen] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Retiro_Dinero]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Retiro_Dinero](
	[id_retiro_dinero] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NULL,
	[monto] [decimal](12, 2) NULL CONSTRAINT [DF_Retiro_Dinero_monto]  DEFAULT ((0)),
	[id_informacion_bancaria_destino] [int] NULL,
	[cod_respuesta_interno] [int] NULL,
	[cod_respuesta_servicio] [int] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Retiro_Dinero_version]  DEFAULT ((0)),
	[nro_control_servicio] [varchar](4) NULL,
	[nro_transaccion_servicio] [varchar](6) NULL,
	[estado_transaccion] [varchar](20) NULL,
 CONSTRAINT [PK_Retiro_Dinero] PRIMARY KEY CLUSTERED 
(
	[id_retiro_dinero] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Retiro_Dinero_Base24]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Retiro_Dinero_Base24](
	[id_retiro_dinero_Base24] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[fecha_negocio] [datetime] NULL,
	[fecha_retiro_dinero] [datetime] NULL,
	[nro_transaccion_servicio] [varchar](6) NULL,
	[cbu_usuario] [varchar](22) NOT NULL,
	[monto] [decimal](12, 2) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
	[estado_transaccion] [varchar](20) NULL,
 CONSTRAINT [PK_Retiro_Dinero_Base24] PRIMARY KEY CLUSTERED 
(
	[id_retiro_dinero_Base24] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Retiro_Dinero_Base24_Aux]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Retiro_Dinero_Base24_Aux](
	[id_retiro_dinero_Base24] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[fecha_negocio] [datetime] NULL,
	[fecha_retiro_dinero] [datetime] NULL,
	[nro_transaccion_servicio] [varchar](6) NULL,
	[cbu_usuario] [varchar](22) NOT NULL,
	[monto] [decimal](12, 2) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
	[estado_transaccion] [varchar](20) NULL,
 CONSTRAINT [PK_Retiro_Dinero_Base24_AUX] PRIMARY KEY CLUSTERED 
(
	[id_retiro_dinero_Base24] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Rubro]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Rubro](
	[id_rubro] [int] NOT NULL,
	[codigo_rubro] [varchar](4) NOT NULL,
	[descripcion] [varchar](40) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Rubro_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Rubro] PRIMARY KEY CLUSTERED 
(
	[id_rubro] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Saldo_De_Cuenta_Tmp]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Saldo_De_Cuenta_Tmp](
	[I] [int] NOT NULL,
	[LocationIdentification] [int] NULL,
	[Saldo] [decimal](12, 2) NULL,
	[CantidadCompras] [int] NULL,
 CONSTRAINT [PK_Saldo_De_Cuenta_Tmp] PRIMARY KEY CLUSTERED 
(
	[I] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Site_Transaccion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Site_Transaccion](
	[id_site_transaccion] [int] NOT NULL,
	[tipo_transaccion] [varchar](50) NOT NULL,
	[id_tipo_concepto_boton] [int] NULL,
	[flag_transaccion_con_cvv] [bit] NOT NULL DEFAULT ((0)),
	[id_vertical_cs] [int] NULL,
	[id_canal] [int] NULL,
	[nro_agrupador_decidir] [int] NOT NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL DEFAULT (NULL),
	[usuario_modificacion] [varchar](20) NULL DEFAULT (NULL),
	[fecha_baja] [datetime] NULL DEFAULT (NULL),
	[usuario_baja] [varchar](20) NULL DEFAULT (NULL),
	[version] [int] NOT NULL DEFAULT ('0'),
	[tipo_pago] [varchar](50) NOT NULL DEFAULT ('ONLINE'),
PRIMARY KEY CLUSTERED 
(
	[id_site_transaccion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Situacion_Fiscal_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Situacion_Fiscal_Cuenta](
	[id_situacion_fiscal] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NULL,
	[numero_CUIT] [varchar](11) NULL,
	[razon_social] [varchar](50) NULL,
	[id_domicilio_facturacion] [int] NULL,
	[id_tipo_condicion_IVA] [int] NULL,
	[porcentaje_exclusion_iva] [decimal](5, 2) NULL,
	[fecha_hasta_exclusion_IVA] [datetime] NULL,
	[id_tipo_condicion_IIBB] [int] NULL,
	[porcentaje_exclusion_IIBB] [decimal](5, 2) NULL,
	[fecha_hasta_exclusion_IIBB] [datetime] NULL,
	[id_estado_documentacion] [int] NOT NULL,
	[id_motivo_estado] [int] NULL,
	[flag_vigente] [bit] NULL,
	[fecha_inicio_vigencia] [date] NULL,
	[fecha_fin_vigencia] [date] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[fecha_validacion] [datetime] NULL,
	[usuario_validador] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Situacion_Fiscal_Cuenta_version]  DEFAULT ((0)),
	[flag_validacion_excepcion] [bit] NULL,
	[nro_inscripcion_IIBB] [varchar](20) NULL,
 CONSTRAINT [PK_Situacion_Fiscal_Cuenta] PRIMARY KEY CLUSTERED 
(
	[id_situacion_fiscal] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Tamanio_Boton]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Tamanio_Boton](
	[id_tamano_boton] [int] NOT NULL,
	[descripcion] [varchar](20) NULL,
	[valor] [varchar](20) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Tamanio_Boton_version]  DEFAULT ((0)),
	[alto] [float] NULL,
	[ancho] [float] NULL,
 CONSTRAINT [PK_Tamanio_Boton] PRIMARY KEY CLUSTERED 
(
	[id_tamano_boton] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Tasa_MP]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Tasa_MP](
	[id_tasa_mp] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_medio_pago] [int] NOT NULL,
	[cant_cuotas] [int] NOT NULL,
	[coeficiente] [decimal](6, 4) NOT NULL,
	[tasa_directa] [decimal](5, 2) NOT NULL,
	[tna] [decimal](5, 2) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Tasa_MP_version]  DEFAULT ((0)),
	[fecha_inicio_vigencia] [date] NOT NULL,
	[fecha_fin_vigencia] [date] NULL,
 CONSTRAINT [PK_Tasa_MP] PRIMARY KEY CLUSTERED 
(
	[id_tasa_mp] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Tipo]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Tipo](
	[id_tipo] [int] NOT NULL,
	[id_grupo_tipo] [int] NOT NULL,
	[codigo] [varchar](20) NULL,
	[descripcion] [varchar](100) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Tipo_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Tipo] PRIMARY KEY CLUSTERED 
(
	[id_tipo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY],
 CONSTRAINT [UQ_Tipo_codigo] UNIQUE NONCLUSTERED 
(
	[codigo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Tipo_Cambio_Pendiente]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [dbo].[Tipo_Cambio_Pendiente](
	[id_tipo_cambio] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[codigo] [varchar](20) NOT NULL,
	[tabla_destino] [varchar](50) NOT NULL,
	[campo_destino] [varchar](50) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Tipo_Cambio_Pendiente_version]  DEFAULT ((0)),
 CONSTRAINT [PK_id_tipo_cambio] PRIMARY KEY CLUSTERED 
(
	[id_tipo_cambio] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Tipo_Cargo]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Tipo_Cargo](
	[id_tipo_cargo] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[codigo] [varchar](20) NOT NULL,
	[descripcion] [varchar](100) NOT NULL,
	[signo] [char](1) NOT NULL,
	[flag_configura_panel] [bit] NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
	[flag_aplica_iva] [bit] NOT NULL,
 CONSTRAINT [PK_Tipo_Cargo] PRIMARY KEY CLUSTERED 
(
	[id_tipo_cargo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Tipo_Comprobante_Facturacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Tipo_Comprobante_Facturacion](
	[id_tipo_comprobante_fact] [int] NOT NULL,
	[tipo_comprobante] [char](1) NOT NULL,
	[punto_venta] [char](1) NOT NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL DEFAULT (NULL),
	[usuario_modificacion] [varchar](20) NULL DEFAULT (NULL),
	[fecha_baja] [datetime] NULL DEFAULT (NULL),
	[usuario_baja] [datetime] NULL DEFAULT (NULL),
	[version] [int] NOT NULL DEFAULT ('0'),
	[letra_comprobante] [char](1) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_tipo_comprobante_fact] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Tipo_Dato_Pendiente_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [dbo].[Tipo_Dato_Pendiente_Cuenta](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[tipo_dato_pendiente] [varchar](30) NOT NULL,
	[id_tipo_cuenta] [int] NOT NULL,
	[id_tipo_cambio] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Tipo_Dato_Pendiente_Cuenta_version]  DEFAULT ((0)),
 CONSTRAINT [PK_id_Tipo_Dato_Pendiente_Cuenta] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Tipo_Facturacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Tipo_Facturacion](
	[id_tipo_facturacion] [int] NOT NULL,
	[id_tipo] [int] NOT NULL,
	[codigo_facturacion] [int] NOT NULL,
	[descripcion_facturacion] [varchar](50) NOT NULL,
	[descripcion_corta] [varchar](30) NOT NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL,
 CONSTRAINT [id_tipo_facturacion] PRIMARY KEY CLUSTERED 
(
	[id_tipo_facturacion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Tipo_Medio_Pago]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Tipo_Medio_Pago](
	[id_tipo_medio_pago] [int] NOT NULL,
	[codigo] [varchar](20) NOT NULL CONSTRAINT [DF_Tipo_Medio_Pago_codigo]  DEFAULT (''),
	[nombre] [varchar](20) NOT NULL,
	[flag_permite_anulacion] [bit] NOT NULL CONSTRAINT [DF_Tipo_Medio_Pago_flag_permite_anulacion]  DEFAULT ((0)),
	[flag_permite_devolucion] [bit] NOT NULL CONSTRAINT [DF_Tipo_Medio_Pago_flag_permi]  DEFAULT ((0)),
	[plazo_devolucion] [int] NULL CONSTRAINT [DF_Tipo_Medio_Pago_plazo_devo]  DEFAULT (NULL),
	[flag_opera_cuotas] [bit] NOT NULL CONSTRAINT [DF_Tipo_Medio_Pago_flag_opera]  DEFAULT ((0)),
	[id_tipo_acreditacion] [int] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Tipo_Medio_Pago_version]  DEFAULT ((0)),
	[flag_permite_contracargo] [bit] NOT NULL DEFAULT ((0)),
	[flag_permitido_billetera] [bit] NOT NULL CONSTRAINT [DF_TipoMP_permitido_billetera]  DEFAULT ((0)),
 CONSTRAINT [PK_Tipo_Medio_Pago] PRIMARY KEY CLUSTERED 
(
	[id_tipo_medio_pago] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Tipo_Parametro]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Tipo_Parametro](
	[id_tipo_parametro] [int] NOT NULL,
	[nombre] [varchar](100) NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Tipo_Parametro_version]  DEFAULT ((0)),
 CONSTRAINT [PK_Tipo_Parametro] PRIMARY KEY CLUSTERED 
(
	[id_tipo_parametro] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Tipo_Transaccion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Tipo_Transaccion](
	[id_tipo_transaccion] [int] NOT NULL,
	[descripcion] [varchar](50) NULL,
	[descripcion_a_mostrar] [varchar](20) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Tipo_Transaccion_version]  DEFAULT ((0)),
	[vision] [varchar](20) NULL,
 CONSTRAINT [PK_Tipo_Transaccion] PRIMARY KEY CLUSTERED 
(
	[id_tipo_transaccion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[TyC]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[TyC](
	[id_version] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[version_TyC] [int] NOT NULL,
	[fecha_vigencia_desde] [datetime] NOT NULL,
	[fecha_vigencia_hasta] [datetime] NULL,
	[path_texto] [varchar](255) NOT NULL,
	[estado_activo] [bit] NOT NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_TyC_version]  DEFAULT ((0)),
 CONSTRAINT [PK_TyC] PRIMARY KEY CLUSTERED 
(
	[id_version] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Usuario_Cuenta]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Usuario_Cuenta](
	[id_usuario_cuenta] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_cuenta] [int] NULL,
	[eMail] [varchar](50) NOT NULL,
	[mail_confirmado] [bit] NULL,
	[id_pregunta_seguridad] [int] NULL,
	[respuesta_pregunta_seguridad] [varchar](50) NULL,
	[password] [varchar](50) NULL,
	[ultimas_password] [varchar](100) NULL,
	[password_bloqueada] [bit] NOT NULL,
	[intentos_login] [int] NOT NULL,
	[ultima_modificacion_password] [datetime] NULL,
	[fecha_ultimo_login] [datetime] NULL,
	[ip_ultimo_login] [varchar](20) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Usuario_Cuenta_version]  DEFAULT ((0)),
	[id_estado_mail] [int] NULL,
	[perfil] [varchar](20) NULL,
	[fecha_ultimo_bloqueo] [datetime] NULL,
 CONSTRAINT [PK_Usuario_Cuenta] PRIMARY KEY CLUSTERED 
(
	[id_usuario_cuenta] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[VencMediosDePago_tmp]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[VencMediosDePago_tmp](
	[I] [int] NOT NULL,
	[id_medio_pago_cuenta] [int] NULL,
	[id_cuenta] [int] NULL,
	[codigo] [varchar](20) NULL,
	[denominacion1] [varchar](80) NULL,
	[denominacion2] [varchar](80) NULL,
	[mascara_numero_tarjeta] [varchar](20) NULL,
	[email] [varchar](50) NULL,
	[fecha_vencimiento] [varchar](10) NULL,
	[flag_tipo_de_medio] [varchar](20) NULL,
	[flag_error_informado] [bit] NULL,
	[id_error_BIN] [varchar](80) NULL,
 CONSTRAINT [PK_VencMediosDePago_tmp] PRIMARY KEY CLUSTERED 
(
	[I] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Vertical_Cybersource]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Vertical_Cybersource](
	[id_vertical_CS] [int] NOT NULL,
	[codigo_vertical] [varchar](20) NOT NULL,
	[description] [varchar](40) NULL,
	[fecha_alta] [datetime] NULL,
	[usuario_alta] [varchar](20) NULL,
	[fecha_modificacion] [datetime] NULL DEFAULT (NULL),
	[usuario_modificacion] [varchar](20) NULL DEFAULT (NULL),
	[fecha_baja] [datetime] NULL DEFAULT (NULL),
	[usuario_baja] [varchar](20) NULL DEFAULT (NULL),
	[version] [int] NOT NULL DEFAULT ('0'),
PRIMARY KEY CLUSTERED 
(
	[id_vertical_CS] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[volumen_regla_promocion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[volumen_regla_promocion](
	[id_volumen_rp] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[id_regla_promocion] [int] NOT NULL,
	[volumen_vta_desde] [decimal](18, 2) NULL,
	[volumen_vta_hasta] [decimal](18, 2) NULL,
	[bonificacion_cf_vendedor] [decimal](5, 2) NOT NULL,
	[fecha_alta] [datetime] NOT NULL,
	[usuario_alta] [varchar](20) NOT NULL,
	[fecha_modificacion] [datetime] NULL,
	[usuario_modificacion] [varchar](20) NULL,
	[fecha_baja] [datetime] NULL,
	[usuario_baja] [varchar](20) NULL,
	[version] [int] NOT NULL CONSTRAINT [DF_Volumen_Regla_Promocion_version]  DEFAULT ((0)),
PRIMARY KEY CLUSTERED 
(
	[id_volumen_rp] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[vuelta_facturacion]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [dbo].[vuelta_facturacion](
	[id_vuelta_facturacion] [int] NULL,
	[Nro_item] [char](10) NULL,
	[Nro_Interno] [numeric](9, 0) NULL,
	[Mascara] [char](4) NULL,
	[Descripcion_item] [char](20) NULL,
	[Rango_precio] [char](100) NULL,
	[Codigo_contrato] [numeric](9, 0) NULL,
	[Desc_contrato] [char](30) NULL,
	[Tipo_comprobante] [char](2) NULL,
	[Fecha_comprobante] [date] NULL,
	[Nro_cliente_int] [numeric](9, 0) NULL,
	[Descripcion_cliente] [char](80) NULL,
	[Nro_comprobante] [numeric](9, 0) NULL,
	[Cantidad] [numeric](15, 5) NULL,
	[Cantidad_medida] [char](6) NULL,
	[Importe_dolares] [decimal](18, 2) NULL,
	[Importe_dolares_iva] [decimal](18, 2) NULL,
	[Importe_pesos] [decimal](15, 5) NULL,
	[Importe_pesos_iva] [decimal](18, 2) NULL,
	[Campania] [numeric](9, 0) NULL,
	[Nro_cliente_ext] [char](10) NULL
) ON [PRIMARY]
SET ANSI_PADDING ON
ALTER TABLE [dbo].[vuelta_facturacion] ADD [Letra_comprobante] [char](1) NULL

GO
SET ANSI_PADDING OFF
GO
/****** Object:  View [dbo].[TransactionsView]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[TransactionsView] AS
select 
       t.Id as id, 
       t.CreateTimestamp as fecha,
       t.CredentialEmailAddress as cliente, 
       t.saleConcept as concepto,
       t.amount as amount,
       t.TransactionStatus as estado,
       t.CredentialMask as CredentialMask,
       t.CredentialHolderName as CredentialHolderName,
       t.CreateTimeStamp as CreateTimeStSaleConceptamp,
       t.CredentialEmailAddress as CredencialEmailAddress,
       t.AvailableTimestamp as AvailableTimestamp,
       t.ProductIdentification as ProductIdentification,
       t.ProviderTransactionID as ProviderTransactionID,
       t.LiquidationTimestamp as LiquidationTimestamp,
       t.CouponExpirationDate as CouponExpirationDate,
       t.TaxAmount as TaxAmount,
       t.FeeAmount as FeeAmount,
       t.CouponStatus as CouponStatus,
       t.ResultCode as ResultCode,
       t.LiquidationStatus as LiquidationStatus,
       t.OperationName as OperationName,
       t.LocationIdentification as locationIdentification,
       t.PaymentTimestamp as PaymentTimestamp,
       'tx' as origin,
       t.CashoutTimestamp as CashoutTimestamp,
       t.ChargebackStatus as ChargebackStatus,
       t.BuyerAccountIdentification as BuyerAccountIdentification,
       t.BankIdentification as BankIdentification,
	   t.CurrencyCode as CurrencyCode,
	   t.facilitiesPayments as FacilitiesPayments,
	   t.OriginalOperationId as OriginalOperationId,
	   t.taxAmountBuyer as taxAmountBuyer,
	   t.amountBuyer as amountBuyer,
       bco.denominacion as BancoDenominacion,
	   cta.denominacion1 as CuentaDenominacion1,
	   cta.denominacion2 as CuentaDenominacion2,
	   usu_cta.eMail as VendedorEmailAddress,
	   t.productType as ProductType,
	   t.resultMessage as ResultMessage,
	   e.nombre as EstadoTransaccion,
	   t.channel as Channel
from Transactions.dbo.transactions t
left join Configurations.dbo.Banco bco
on bco.id_banco = t.bankIdentification
left join Configurations.dbo.Cuenta cta
on cta.id_cuenta = t.LocationIdentification
left join Configurations.dbo.Usuario_Cuenta usu_cta
on usu_cta.id_cuenta = t.LocationIdentification
left join Configurations.dbo.Estado e
on e.codigo = t.TransactionStatus
union all
select (cast (r.id_retiro_dinero as varchar)) 
       as id, 
       r.fecha_alta as fecha,
       NULL as cliente, 
       concat('Transferencia a cuenta ',b.nombre_banco) as concepto,
       r.monto as amount,
       r.estado_transaccion as estado,
       NULL as CredentialMask,
       NULL as CredentialHolderName,
       NULL as CreateTimeStamp,
       NULL as CredencialEmailAddress,
       NULL as AvailableTimestamp,
       NULL as ProductIdentification,
       (cast (r.id_retiro_dinero as varchar)) as ProviderTransactionID,
       NULL as LiquidationTimestamp,
       NULL as CouponExpirationDate,
       NULL as TaxAmount,
       NULL as FeeAmount,
       NULL as CouponStatus,
       r.cod_respuesta_interno as ResultCode,
       NULL as LiquidationStatus,
       'Retiro_de_Dinero' as OperationName,
       r.id_cuenta as locationIdentification,
       null as PaymentTimestamp,
       'rd' as origin,
       null as CashoutTimestamp,
       null as ChargebackStatus,
       null as BuyerAccountIdentification,
       null as BankIdentification,
	   null as CurrencyCode,
	   null as FacilitiesPayments,
	   null as OriginalOperationId,
	   null as taxAmountBuyer,
	   null as amountBuyer,
       null as BancoDenominacion,
	   null as CuentaDenominacion1,
	   null as CuentaDenominacion2,
	   null as VendedorEmailAddress,
	   null as ProductType,
	   null as ResultMessage,
	   e.nombre as EstadoTransaccion,
	   null as channel
from Configurations.dbo.Retiro_Dinero r
right join Configurations.dbo.Informacion_Bancaria_Cuenta b
on r.id_informacion_bancaria_destino = b.id_informacion_bancaria
left join Configurations.dbo.Estado e
on e.codigo = r.estado_transaccion


GO
/****** Object:  View [dbo].[TransactionsViewResumen]    Script Date: 16/03/2016 02:48:58 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE VIEW [dbo].[TransactionsViewResumen] AS
select
	t.Id as Id,
	t.CreateTimestamp as CreateTimestamp,
	t.UpdateTimestamp as UpdateTimestamp,
	t.TransportTimestamp as TransportTimestamp,
	t.RequestInputTimestamp as RequestInputTimestamp,
	t.RequestOutputTimestamp as RequestOutputTimestamp,
	t.AnswerInputTimestamp as AnswerInputTimestamp,
	t.AnswerOutputTimestamp as AnswerOutputTimestamp,
	t.DeviceIdentification as DeviceIdentification,
	t.LocationIdentification as LocationIdentification,
	t.ServiceName as ServiceName,
	t.OperationName as OperationName,
	t.SequenceNumber as SequenceNumber,
	t.Status as Status,
	t.UserIdentification as UserIdentification,
	t.ProviderIdentification as ProviderIdentification,
	t.ProviderTransactionID as ProviderTransactionID,
	t.DeviceTransactionID as DeviceTransactionID,
	t.SyncStatus as SyncStatus,
	t.SyncTimestamp as SyncTimestamp,
	t.ProductIdentification as ProductIdentification,
	t.RetrievalReferenceNumber as RetrievalReferenceNumber,
	t.FacilitiesPayments as FacilitiesPayments,
	t.FacilitiesType as FacilitiesType,
	t.CurrencyCode as CurrencyCode,
	t.Amount as Amount,
	t.FeeAmount as FeeAmount,
	t.TaxAmount as TaxAmount,
	t.ComissionAmount as ComissionAmount,
	t.ServiceChargeAmount as ServiceChargeAmount,
	t.MerchantIdentification as MerchantIdentification,
	t.ProviderDeviceIdentification as ProviderDeviceIdentification,
	t.ReverseStatus as ReverseStatus,
	t.ReverseTimestamp as ReverseTimestamp,
	t.VoidStatus as VoidStatus,
	t.VoidTimestamp as VoidTimestamp,
	t.VoidUserIdentification as VoidUserIdentification,
	t.RefundStatus as RefundStatus,
	t.RefundTimestamp as RefundTimestamp,
	t.RefundUserIdentification as RefundUserIdentification,
	t.RefundAmount as RefundAmount,
	t.CloseStatus as CloseStatus,
	t.CloseTimestamp as CloseTimestamp,
	t.CloseUserIdentification as CloseUserIdentification,
	t.SettlementStatus as SettlementStatus,
	t.SettlementTimestamp as SettlementTimestamp,
	t.SettlementUserIdentification as SettlementUserIdentification,
	t.SettlementAmount as SettlementAmount,
	t.SettlementTransactionId as SettlementTransactionId,
	t.RevisionStatus as RevisionStatus,
	t.RevisionTimestamp as RevisionTimestamp,
	t.RevisionReason as RevisionReason,
	t.RevisionSource as RevisionSource,
	t.BatchNumber as BatchNumber,
	t.TicketNumber as TicketNumber,
	t.ProviderBatchNumber as ProviderBatchNumber,
	t.ProviderTicketNumber as ProviderTicketNumber,
	t.ProviderTraceNumber as ProviderTraceNumber,
	t.ProviderAuthorizationCode as ProviderAuthorizationCode,
	t.CustomerIdentification as CustomerIdentification,
	t.CredentialInputMode as CredentialInputMode,
	t.CredentialMask as CredentialMask,
	t.CredentialEncrypted as CredentialEncrypted,
	t.CredentialExpDate as CredentialExpDate,
	t.CredentialCardHash as CredentialCardHash,
	t.CredentialHolderName as CredentialHolderName,
	t.CredentialAddress as CredentialAddress,
	t.CredentialDocumentType as CredentialDocumentType,
	t.CredentialDocumentNumber as CredentialDocumentNumber,
	t.CredentialEmailAddress as CredentialEmailAddress,
	t.DeviceFingerprint as DeviceFingerprint,
	t.ResultCode as ResultCode,
	t.ResultMessage as ResultMessage,
	t.ProviderResultCode as ProviderResultCode,
	t.ProviderResultMessage as ProviderResultMessage,
	t.Channel as Channel,
	t.CaptureAddress as CaptureAddress,
	t.CaptureTimestamp as CaptureTimestamp,
	t.RequestAddress as RequestAddress,
	t.RequestTimestamp as RequestTimestamp,
	t.AnswerAddress as AnswerAddress,
	t.AnswerTimestamp as AnswerTimestamp,
	t.RedirectURLOK as RedirectURLOK,
	t.RedirectURLError as RedirectURLError,
	t.CredentialBirthday as CredentialBirthday,
	t.BillHolderName as BillHolderName,
	t.BillHolderDocumentType as BillHolderDocumentType,
	t.BillHolderDocumentNumber as BillHolderDocumentNumber,
	t.ProviderCustomerCode as ProviderCustomerCode,
	t.ProviderCustomerAdditionalCode as ProviderCustomerAdditionalCode,
	t.ChargeLatePaymentAmount as ChargeLatePaymentAmount,
	t.DifferenceBetweenFirstExpiration as DifferenceBetweenFirstExpiration,
	t.DaysAfterFirstExpiration as DaysAfterFirstExpiration,
	t.CouponExpirationDate as CouponExpirationDate,
	t.InvoiceExpirationDate as InvoiceExpirationDate,
	t.PaymentBarCode as PaymentBarCode,
	t.InvoiceBarCode as InvoiceBarCode,
	t.LiquidationStatus as LiquidationStatus,
	t.LiquidationTimestamp as LiquidationTimestamp,
	t.ReconciliationStatus as ReconciliationStatus,
	t.ReconciliationTimestamp as ReconciliationTimestamp,
	t.AvailableStatus as AvailableStatus,
	t.AvailableTimestamp as AvailableTimestamp,
	t.AvailableAmount as AvailableAmount,
	t.BillingStatus as BillingStatus,
	t.BillingTimestamp as BillingTimestamp,
	t.ProcessorResultCode as ProcessorResultCode,
	t.ProcessorResultMessage as ProcessorResultMessage,
	t.ButtonId as ButtonId,
	t.ButtonExternalId as ButtonExternalId,
	t.ButtonMinimumAmount as ButtonMinimumAmount,
	t.ButtonMaximumAmount as ButtonMaximumAmount,
	t.SaleConcept as SaleConcept,
	t.MerchantActivityCode as MerchantActivityCode,
	t.ChargebackStatus as ChargebackStatus,
	t.ChargebackTimestamp as ChargebackTimestamp,
	t.ChargebackReason as ChargebackReason,
	t.CashoutStatus as CashoutStatus,
	t.CashoutTimestamp as CashoutTimestamp,
	t.FilingDeadline as FilingDeadline,
	t.PaymentTimestamp as PaymentTimestamp,
	t.PaymentStatus as PaymentStatus,
	t.PaymentDeadline as PaymentDeadline,
	t.CouponStatus as CouponStatus,
	t.CouponDaysBetweenExpDates as CouponDaysBetweenExpDates,
	t.CouponValidityDays as CouponValidityDays,
	t.CouponFee as CouponFee,
	t.CouponSecondExpirationDate as CouponSecondExpirationDate,
	t.CouponClientCode as CouponClientCode,
	t.CouponSubscriber as CouponSubscriber,
	t.CouponOperationId as CouponOperationId,
	t.OriginalOperationId as OriginalOperationId,
	t.TransactionStatus as TransactionStatus,
	t.ProductType as ProductType,
	t.BankIdentification as BankIdentification,
	t.BuyerAccountIdentification as BuyerAccountIdentification,
	t.PrivateRequestKey as PrivateRequestKey,
	t.PublicRequestKey as PublicRequestKey,
	t.PrivateAnswerKey as PrivateAnswerKey,
	t.PublicAnswerKey as PublicAnswerKey,
	t.PublicIdentification as PublicIdentification,
	t.id_medio_pago_cuenta as id_medio_pago_cuenta,
	t.AmountBuyer as AmountBuyer,
	t.FeeAmountBuyer as FeeAmountBuyer,
	t.TaxAmountBuyer as TaxAmountBuyer,
	t.AdditionalData as AdditionalData,
	t.PromotionIdentification as PromotionIdentification,
	btn.id_tipo_concepto_boton as id_tipo_concepto_boton,
	usu_cta.eMail as VendedorEmailAddress
from Transactions.dbo.transactions t
left join Configurations.dbo.Boton btn
on t.ButtonId = btn.id_boton
left join Configurations.dbo.Usuario_Cuenta usu_cta
on usu_cta.id_cuenta = t.LocationIdentification



GO
ALTER TABLE [dbo].[CUIT_Condicionado] ADD  DEFAULT (NULL) FOR [id_motivo_baja]
GO
ALTER TABLE [dbo].[CUIT_Condicionado] ADD  DEFAULT (NULL) FOR [fecha_modificacion]
GO
ALTER TABLE [dbo].[CUIT_Condicionado] ADD  DEFAULT (NULL) FOR [usuario_modificacion]
GO
ALTER TABLE [dbo].[CUIT_Condicionado] ADD  DEFAULT (NULL) FOR [fecha_baja]
GO
ALTER TABLE [dbo].[CUIT_Condicionado] ADD  DEFAULT (NULL) FOR [usuario_baja]
GO
ALTER TABLE [dbo].[CUIT_Condicionado] ADD  DEFAULT ((0)) FOR [version]
GO
ALTER TABLE [dbo].[Lista_Negra_Clave] ADD  CONSTRAINT [DF_Lista_Negra_Clave_version]  DEFAULT ((0)) FOR [version]
GO
ALTER TABLE [dbo].[Lista_Negra_Telefono] ADD  CONSTRAINT [DF_Lista_Negra_Telefono_version]  DEFAULT ((0)) FOR [version]
GO
ALTER TABLE [dbo].[Log_Validacion_Link] ADD  DEFAULT ((0)) FOR [version]
GO
ALTER TABLE [dbo].[Plan] ADD  CONSTRAINT [DF_Plan_version]  DEFAULT ((0)) FOR [version]
GO
ALTER TABLE [dbo].[Promocion_Medio_Pago] ADD  CONSTRAINT [DF_Promocion_Medio_Pago_version]  DEFAULT ((0)) FOR [version]
GO
ALTER TABLE [dbo].[Promocion_Medio_Pago_Banco] ADD  CONSTRAINT [DF_Promocion_Medio_Pago_Banco_version]  DEFAULT ((0)) FOR [version]
GO
ALTER TABLE [dbo].[Accion_Limite]  WITH CHECK ADD  CONSTRAINT [FK_Accion_Limite_id_tipo_accion_limite] FOREIGN KEY([id_tipo_accion_limite])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Accion_Limite] CHECK CONSTRAINT [FK_Accion_Limite_id_tipo_accion_limite]
GO
ALTER TABLE [dbo].[Accion_Limite]  WITH CHECK ADD  CONSTRAINT [FK_Accion_Limite_id_tipo_aplicacion_limite] FOREIGN KEY([id_tipo_aplicacion_limite])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Accion_Limite] CHECK CONSTRAINT [FK_Accion_Limite_id_tipo_aplicacion_limite]
GO
ALTER TABLE [dbo].[Accion_Limite]  WITH CHECK ADD  CONSTRAINT [FK_Accion_Limite_id_tipo_limite] FOREIGN KEY([id_tipo_limite])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Accion_Limite] CHECK CONSTRAINT [FK_Accion_Limite_id_tipo_limite]
GO
ALTER TABLE [dbo].[ACL_BANCO]  WITH CHECK ADD  CONSTRAINT [fk_id_banco_2] FOREIGN KEY([id_banco])
REFERENCES [dbo].[Banco] ([id_banco])
GO
ALTER TABLE [dbo].[ACL_BANCO] CHECK CONSTRAINT [fk_id_banco_2]
GO
ALTER TABLE [dbo].[Actividad_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Actividad_Cuenta_Actividad_AFIP] FOREIGN KEY([id_actividad_AFIP])
REFERENCES [dbo].[Actividad_AFIP] ([id_actividad_AFIP])
GO
ALTER TABLE [dbo].[Actividad_Cuenta] CHECK CONSTRAINT [FK_Actividad_Cuenta_Actividad_AFIP]
GO
ALTER TABLE [dbo].[Actividad_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Actividad_Cuenta_Estado] FOREIGN KEY([id_estado_actividad])
REFERENCES [dbo].[Estado] ([id_estado])
GO
ALTER TABLE [dbo].[Actividad_Cuenta] CHECK CONSTRAINT [FK_Actividad_Cuenta_Estado]
GO
ALTER TABLE [dbo].[Actividad_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Actividad_Cuenta_Rubro] FOREIGN KEY([id_rubro])
REFERENCES [dbo].[Rubro] ([id_rubro])
GO
ALTER TABLE [dbo].[Actividad_Cuenta] CHECK CONSTRAINT [FK_Actividad_Cuenta_Rubro]
GO
ALTER TABLE [dbo].[Actividad_MP_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Actividad_MP_Cuenta_id_mp_cuenta] FOREIGN KEY([id_mp_cuenta])
REFERENCES [dbo].[Medio_Pago_Cuenta] ([id_medio_pago_cuenta])
GO
ALTER TABLE [dbo].[Actividad_MP_Cuenta] CHECK CONSTRAINT [FK_Actividad_MP_Cuenta_id_mp_cuenta]
GO
ALTER TABLE [dbo].[Actividad_Transaccional_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Actividad_Transaccional__Actividad_Transaccional_] FOREIGN KEY([id_actividad_cuenta])
REFERENCES [dbo].[Actividad_Transaccional_Cuenta] ([id_actividad_cuenta])
GO
ALTER TABLE [dbo].[Actividad_Transaccional_Cuenta] CHECK CONSTRAINT [FK_Actividad_Transaccional__Actividad_Transaccional_]
GO
ALTER TABLE [dbo].[Actividad_Transaccional_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Actividad_Transaccional__Log_Proceso] FOREIGN KEY([id_log_proceso])
REFERENCES [dbo].[Log_Proceso] ([id_log_proceso])
GO
ALTER TABLE [dbo].[Actividad_Transaccional_Cuenta] CHECK CONSTRAINT [FK_Actividad_Transaccional__Log_Proceso]
GO
ALTER TABLE [dbo].[Acumulador_Promociones]  WITH CHECK ADD  CONSTRAINT [FK_Acumulador_Promociones_Promocion] FOREIGN KEY([id_promocion])
REFERENCES [dbo].[Promocion] ([id_promocion])
GO
ALTER TABLE [dbo].[Acumulador_Promociones] CHECK CONSTRAINT [FK_Acumulador_Promociones_Promocion]
GO
ALTER TABLE [dbo].[Ajuste]  WITH CHECK ADD  CONSTRAINT [FK_Ajuste_Codigo_Operacion] FOREIGN KEY([id_codigo_operacion])
REFERENCES [dbo].[Codigo_Operacion] ([id_codigo_operacion])
GO
ALTER TABLE [dbo].[Ajuste] CHECK CONSTRAINT [FK_Ajuste_Codigo_Operacion]
GO
ALTER TABLE [dbo].[Ajuste]  WITH CHECK ADD  CONSTRAINT [FK_Ajuste_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Ajuste] CHECK CONSTRAINT [FK_Ajuste_Cuenta]
GO
ALTER TABLE [dbo].[Ajuste]  WITH CHECK ADD  CONSTRAINT [FK_Ajuste_Motivo] FOREIGN KEY([id_motivo_ajuste])
REFERENCES [dbo].[Motivo_Ajuste] ([id_motivo_ajuste])
GO
ALTER TABLE [dbo].[Ajuste] CHECK CONSTRAINT [FK_Ajuste_Motivo]
GO
ALTER TABLE [dbo].[Banco]  WITH CHECK ADD  CONSTRAINT [fk_id_tipo_acreditacion] FOREIGN KEY([id_tipo_acreditacion])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Banco] CHECK CONSTRAINT [fk_id_tipo_acreditacion]
GO
ALTER TABLE [dbo].[Bin_Banco_Medio_Pago]  WITH CHECK ADD  CONSTRAINT [FK_Bin_Banco_Medio_Pago_Banco] FOREIGN KEY([id_banco])
REFERENCES [dbo].[Banco] ([id_banco])
GO
ALTER TABLE [dbo].[Bin_Banco_Medio_Pago] CHECK CONSTRAINT [FK_Bin_Banco_Medio_Pago_Banco]
GO
ALTER TABLE [dbo].[Bin_Banco_Medio_Pago]  WITH CHECK ADD  CONSTRAINT [FK_Bin_Banco_Medio_Pago_Medio_De_Pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Bin_Banco_Medio_Pago] CHECK CONSTRAINT [FK_Bin_Banco_Medio_Pago_Medio_De_Pago]
GO
ALTER TABLE [dbo].[Boton]  WITH NOCHECK ADD  CONSTRAINT [FK_boton_apariencia_boton] FOREIGN KEY([id_apariencia_boton])
REFERENCES [dbo].[Apariencia_Boton] ([id_apariencia_boton])
GO
ALTER TABLE [dbo].[Boton] CHECK CONSTRAINT [FK_boton_apariencia_boton]
GO
ALTER TABLE [dbo].[Boton]  WITH NOCHECK ADD  CONSTRAINT [FK_Boton_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Boton] CHECK CONSTRAINT [FK_Boton_Cuenta]
GO
ALTER TABLE [dbo].[Boton]  WITH NOCHECK ADD  CONSTRAINT [FK_Boton_Tipo_id_tipo_boton] FOREIGN KEY([id_tipo_boton])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Boton] CHECK CONSTRAINT [FK_Boton_Tipo_id_tipo_boton]
GO
ALTER TABLE [dbo].[Boton]  WITH NOCHECK ADD  CONSTRAINT [FK_Boton_Tipo_id_tipo_concepto_boton] FOREIGN KEY([id_tipo_concepto_boton])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Boton] CHECK CONSTRAINT [FK_Boton_Tipo_id_tipo_concepto_boton]
GO
ALTER TABLE [dbo].[Cambio_Pendiente]  WITH NOCHECK ADD  CONSTRAINT [FK_Cambio_Pendiente_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Cambio_Pendiente] CHECK CONSTRAINT [FK_Cambio_Pendiente_Cuenta]
GO
ALTER TABLE [dbo].[Cambio_Pendiente]  WITH NOCHECK ADD  CONSTRAINT [FK_Cambio_Pendiente_Estado] FOREIGN KEY([id_estado_cambio])
REFERENCES [dbo].[Estado] ([id_estado])
GO
ALTER TABLE [dbo].[Cambio_Pendiente] CHECK CONSTRAINT [FK_Cambio_Pendiente_Estado]
GO
ALTER TABLE [dbo].[Cargo]  WITH CHECK ADD  CONSTRAINT [FK_Cargo_Tipo_Cargo] FOREIGN KEY([id_tipo_cargo])
REFERENCES [dbo].[Tipo_Cargo] ([id_tipo_cargo])
GO
ALTER TABLE [dbo].[Cargo] CHECK CONSTRAINT [FK_Cargo_Tipo_Cargo]
GO
ALTER TABLE [dbo].[Cargo]  WITH NOCHECK ADD  CONSTRAINT [FK_Cargo_Tipo_id_base_de_calculo] FOREIGN KEY([id_base_de_calculo])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Cargo] CHECK CONSTRAINT [FK_Cargo_Tipo_id_base_de_calculo]
GO
ALTER TABLE [dbo].[Cargo]  WITH NOCHECK ADD  CONSTRAINT [FK_Cargo_Tipo_id_tipo_aplicacion] FOREIGN KEY([id_tipo_aplicacion])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Cargo] CHECK CONSTRAINT [FK_Cargo_Tipo_id_tipo_aplicacion]
GO
ALTER TABLE [dbo].[Cargo]  WITH NOCHECK ADD  CONSTRAINT [FK_Cargo_Tipo_id_tipo_cuenta] FOREIGN KEY([id_tipo_cuenta])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Cargo] CHECK CONSTRAINT [FK_Cargo_Tipo_id_tipo_cuenta]
GO
ALTER TABLE [dbo].[Cargo]  WITH NOCHECK ADD  CONSTRAINT [FK_Cargo_Tipo_Medio_Pago] FOREIGN KEY([id_tipo_medio_pago])
REFERENCES [dbo].[Tipo_Medio_Pago] ([id_tipo_medio_pago])
GO
ALTER TABLE [dbo].[Cargo] CHECK CONSTRAINT [FK_Cargo_Tipo_Medio_Pago]
GO
ALTER TABLE [dbo].[Cargo_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Cargo_Cuenta_Cargo] FOREIGN KEY([id_cargo])
REFERENCES [dbo].[Cargo] ([id_cargo])
GO
ALTER TABLE [dbo].[Cargo_Cuenta] CHECK CONSTRAINT [FK_Cargo_Cuenta_Cargo]
GO
ALTER TABLE [dbo].[Cargo_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Cargo_Cuenta_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Cargo_Cuenta] CHECK CONSTRAINT [FK_Cargo_Cuenta_Cuenta]
GO
ALTER TABLE [dbo].[Cargo_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Cargo_Cuenta_Tipo] FOREIGN KEY([id_tipo_aplicacion])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Cargo_Cuenta] CHECK CONSTRAINT [FK_Cargo_Cuenta_Tipo]
GO
ALTER TABLE [dbo].[Cargos_Por_Transaccion]  WITH CHECK ADD  CONSTRAINT [FK_Cargos_Por_Transaccion_Id_Cargo] FOREIGN KEY([id_cargo])
REFERENCES [dbo].[Cargo] ([id_cargo])
GO
ALTER TABLE [dbo].[Cargos_Por_Transaccion] CHECK CONSTRAINT [FK_Cargos_Por_Transaccion_Id_Cargo]
GO
ALTER TABLE [dbo].[Cargos_Por_Transaccion]  WITH CHECK ADD  CONSTRAINT [FK_Cargos_Por_Transaccion_Id_Tipo] FOREIGN KEY([id_tipo_aplicacion])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Cargos_Por_Transaccion] CHECK CONSTRAINT [FK_Cargos_Por_Transaccion_Id_Tipo]
GO
ALTER TABLE [dbo].[Codigo_Operacion_Medio_Pago]  WITH NOCHECK ADD  CONSTRAINT [FK_Codigo_Operacion_Medio_Pago_Codigo_Operacion] FOREIGN KEY([id_codigo_operacion])
REFERENCES [dbo].[Codigo_Operacion] ([id_codigo_operacion])
GO
ALTER TABLE [dbo].[Codigo_Operacion_Medio_Pago] CHECK CONSTRAINT [FK_Codigo_Operacion_Medio_Pago_Codigo_Operacion]
GO
ALTER TABLE [dbo].[Codigo_Operacion_Medio_Pago]  WITH NOCHECK ADD  CONSTRAINT [FK_Codigo_Operacion_Medio_Pago_Medio_De_Pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Codigo_Operacion_Medio_Pago] CHECK CONSTRAINT [FK_Codigo_Operacion_Medio_Pago_Medio_De_Pago]
GO
ALTER TABLE [dbo].[Codigo_Respuesta_Resolutor]  WITH CHECK ADD  CONSTRAINT [FK_Codigo_Respuesta_Resolutor_id_mensaje] FOREIGN KEY([id_mensaje])
REFERENCES [dbo].[Mensaje] ([id_mensaje])
GO
ALTER TABLE [dbo].[Codigo_Respuesta_Resolutor] CHECK CONSTRAINT [FK_Codigo_Respuesta_Resolutor_id_mensaje]
GO
ALTER TABLE [dbo].[Codigo_Respuesta_Resolutor]  WITH CHECK ADD  CONSTRAINT [FK_Codigo_Respuesta_Resolutor_id_resolutor] FOREIGN KEY([id_resolutor])
REFERENCES [dbo].[Resolutor_Transaccion] ([id_resolutor])
GO
ALTER TABLE [dbo].[Codigo_Respuesta_Resolutor] CHECK CONSTRAINT [FK_Codigo_Respuesta_Resolutor_id_resolutor]
GO
ALTER TABLE [dbo].[Comercio_Prisma]  WITH NOCHECK ADD  CONSTRAINT [FK_Comercio_Prisma_id_banco] FOREIGN KEY([id_banco])
REFERENCES [dbo].[Banco] ([id_banco])
GO
ALTER TABLE [dbo].[Comercio_Prisma] CHECK CONSTRAINT [FK_Comercio_Prisma_id_banco]
GO
ALTER TABLE [dbo].[Conciliacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Conciliacion_Conciliacion_Manual] FOREIGN KEY([id_conciliacion_manual])
REFERENCES [dbo].[Conciliacion_Manual] ([id_conciliacion_manual])
GO
ALTER TABLE [dbo].[Conciliacion] CHECK CONSTRAINT [FK_Conciliacion_Conciliacion_Manual]
GO
ALTER TABLE [dbo].[Conciliacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Conciliacion_Log_Paso_Proceso] FOREIGN KEY([id_log_paso])
REFERENCES [dbo].[Log_Paso_Proceso] ([id_log_paso])
GO
ALTER TABLE [dbo].[Conciliacion] CHECK CONSTRAINT [FK_Conciliacion_Log_Paso_Proceso]
GO
ALTER TABLE [dbo].[Conciliacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Conciliacion_Movimiento_Presentado_MP] FOREIGN KEY([id_movimiento_mp])
REFERENCES [dbo].[Movimiento_Presentado_MP] ([id_movimiento_mp])
GO
ALTER TABLE [dbo].[Conciliacion] CHECK CONSTRAINT [FK_Conciliacion_Movimiento_Presentado_MP]
GO
ALTER TABLE [dbo].[Conciliacion_Manual]  WITH NOCHECK ADD  CONSTRAINT [FK_Conciliacion_Manual_Log_Paso_Proceso] FOREIGN KEY([id_log_paso])
REFERENCES [dbo].[Log_Paso_Proceso] ([id_log_paso])
GO
ALTER TABLE [dbo].[Conciliacion_Manual] CHECK CONSTRAINT [FK_Conciliacion_Manual_Log_Paso_Proceso]
GO
ALTER TABLE [dbo].[Conciliacion_Manual]  WITH NOCHECK ADD  CONSTRAINT [FK_Conciliacion_Manual_Movimiento_Presentado_MP] FOREIGN KEY([id_movimiento_mp])
REFERENCES [dbo].[Movimiento_Presentado_MP] ([id_movimiento_mp])
GO
ALTER TABLE [dbo].[Conciliacion_Manual] CHECK CONSTRAINT [FK_Conciliacion_Manual_Movimiento_Presentado_MP]
GO
ALTER TABLE [dbo].[Configuracion_Conciliacion]  WITH CHECK ADD FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Contacto_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Contacto_Cuenta_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Contacto_Cuenta] CHECK CONSTRAINT [FK_Contacto_Cuenta_Cuenta]
GO
ALTER TABLE [dbo].[Contacto_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Contacto_Cuenta_id_operador_celular] FOREIGN KEY([id_operador_celular])
REFERENCES [dbo].[Operador_Celular] ([id_operador_celular])
GO
ALTER TABLE [dbo].[Contacto_Cuenta] CHECK CONSTRAINT [FK_Contacto_Cuenta_id_operador_celular]
GO
ALTER TABLE [dbo].[Contacto_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Contacto_Cuenta_Tipo] FOREIGN KEY([id_tipo_identificacion])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Contacto_Cuenta] CHECK CONSTRAINT [FK_Contacto_Cuenta_Tipo]
GO
ALTER TABLE [dbo].[Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Cuenta_Canal_Adhesion] FOREIGN KEY([id_canal])
REFERENCES [dbo].[Canal_Adhesion] ([id_canal])
GO
ALTER TABLE [dbo].[Cuenta] CHECK CONSTRAINT [FK_Cuenta_Canal_Adhesion]
GO
ALTER TABLE [dbo].[Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Cuenta_Estado] FOREIGN KEY([id_estado_cuenta])
REFERENCES [dbo].[Estado] ([id_estado])
GO
ALTER TABLE [dbo].[Cuenta] CHECK CONSTRAINT [FK_Cuenta_Estado]
GO
ALTER TABLE [dbo].[Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Cuenta_id_banco_adhesion] FOREIGN KEY([id_banco_adhesion])
REFERENCES [dbo].[Banco] ([id_banco])
GO
ALTER TABLE [dbo].[Cuenta] CHECK CONSTRAINT [FK_Cuenta_id_banco_adhesion]
GO
ALTER TABLE [dbo].[Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Cuenta_id_operador_celular] FOREIGN KEY([id_operador_celular])
REFERENCES [dbo].[Operador_Celular] ([id_operador_celular])
GO
ALTER TABLE [dbo].[Cuenta] CHECK CONSTRAINT [FK_Cuenta_id_operador_celular]
GO
ALTER TABLE [dbo].[Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Cuenta_Nacionalidad] FOREIGN KEY([id_nacionalidad])
REFERENCES [dbo].[Nacionalidad] ([id_nacionalidad])
GO
ALTER TABLE [dbo].[Cuenta] CHECK CONSTRAINT [FK_Cuenta_Nacionalidad]
GO
ALTER TABLE [dbo].[Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Cuenta_Tipo_id_tipo_cuenta] FOREIGN KEY([id_tipo_cuenta])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Cuenta] CHECK CONSTRAINT [FK_Cuenta_Tipo_id_tipo_cuenta]
GO
ALTER TABLE [dbo].[Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Cuenta_Tipo_id_tipo_identificacion] FOREIGN KEY([id_tipo_identificacion])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Cuenta] CHECK CONSTRAINT [FK_Cuenta_Tipo_id_tipo_identificacion]
GO
ALTER TABLE [dbo].[Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Cuenta_TyC] FOREIGN KEY([id_version_tyc])
REFERENCES [dbo].[TyC] ([id_version])
GO
ALTER TABLE [dbo].[Cuenta] CHECK CONSTRAINT [FK_Cuenta_TyC]
GO
ALTER TABLE [dbo].[Cuenta_Virtual]  WITH NOCHECK ADD  CONSTRAINT [FK_Cuenta_Virtual_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Cuenta_Virtual] CHECK CONSTRAINT [FK_Cuenta_Virtual_Cuenta]
GO
ALTER TABLE [dbo].[Cuenta_Virtual]  WITH NOCHECK ADD  CONSTRAINT [FK_Cuenta_Virtual_Proceso] FOREIGN KEY([id_proceso_modificacion])
REFERENCES [dbo].[Proceso] ([id_proceso])
GO
ALTER TABLE [dbo].[Cuenta_Virtual] CHECK CONSTRAINT [FK_Cuenta_Virtual_Proceso]
GO
ALTER TABLE [dbo].[Cuenta_Virtual]  WITH NOCHECK ADD  CONSTRAINT [FK_Cuenta_Virtual_Tipo] FOREIGN KEY([id_tipo_cashout])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Cuenta_Virtual] CHECK CONSTRAINT [FK_Cuenta_Virtual_Tipo]
GO
ALTER TABLE [dbo].[CUIT_Condicionado]  WITH CHECK ADD  CONSTRAINT [FK_BANCO_ID_BANCO] FOREIGN KEY([id_banco])
REFERENCES [dbo].[Banco] ([id_banco])
GO
ALTER TABLE [dbo].[CUIT_Condicionado] CHECK CONSTRAINT [FK_BANCO_ID_BANCO]
GO
ALTER TABLE [dbo].[CUIT_Condicionado]  WITH CHECK ADD  CONSTRAINT [FK_DOCUMENTO_ID_DOCUMENTO] FOREIGN KEY([id_documento])
REFERENCES [dbo].[Documento] ([id_documento])
GO
ALTER TABLE [dbo].[CUIT_Condicionado] CHECK CONSTRAINT [FK_DOCUMENTO_ID_DOCUMENTO]
GO
ALTER TABLE [dbo].[CUIT_Condicionado]  WITH CHECK ADD  CONSTRAINT [FK_MOTIVO_ID_MOTIVO_ALTA] FOREIGN KEY([id_motivo_alta])
REFERENCES [dbo].[Motivo] ([id_motivo])
GO
ALTER TABLE [dbo].[CUIT_Condicionado] CHECK CONSTRAINT [FK_MOTIVO_ID_MOTIVO_ALTA]
GO
ALTER TABLE [dbo].[CUIT_Condicionado]  WITH CHECK ADD  CONSTRAINT [FK_MOTIVO_ID_MOTIVO_BAJA] FOREIGN KEY([id_motivo_baja])
REFERENCES [dbo].[Motivo] ([id_motivo])
GO
ALTER TABLE [dbo].[CUIT_Condicionado] CHECK CONSTRAINT [FK_MOTIVO_ID_MOTIVO_BAJA]
GO
ALTER TABLE [dbo].[Dato_Pendiente]  WITH NOCHECK ADD  CONSTRAINT [FK_Dato_Pendiente_Cambio_Pendiente] FOREIGN KEY([id_cambio_pendiente])
REFERENCES [dbo].[Cambio_Pendiente] ([id_cambio_pendiente])
GO
ALTER TABLE [dbo].[Dato_Pendiente] CHECK CONSTRAINT [FK_Dato_Pendiente_Cambio_Pendiente]
GO
ALTER TABLE [dbo].[Dato_Pendiente]  WITH NOCHECK ADD  CONSTRAINT [FK_Dato_Pendiente_id_tipo_cambio] FOREIGN KEY([id_tipo_cambio])
REFERENCES [dbo].[Tipo_Cambio_Pendiente] ([id_tipo_cambio])
GO
ALTER TABLE [dbo].[Dato_Pendiente] CHECK CONSTRAINT [FK_Dato_Pendiente_id_tipo_cambio]
GO
ALTER TABLE [dbo].[Detalle_Facturacion]  WITH CHECK ADD  CONSTRAINT [FK__Detalle_F_id_items_fact] FOREIGN KEY([id_item_facturacion])
REFERENCES [dbo].[Item_Facturacion] ([id_item_facturacion])
GO
ALTER TABLE [dbo].[Detalle_Facturacion] CHECK CONSTRAINT [FK__Detalle_F_id_items_fact]
GO
ALTER TABLE [dbo].[Disputa]  WITH CHECK ADD  CONSTRAINT [FK_disputa_id_cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Disputa] CHECK CONSTRAINT [FK_disputa_id_cuenta]
GO
ALTER TABLE [dbo].[Disputa]  WITH CHECK ADD  CONSTRAINT [FK_disputa_id_estado_resolucion_cuenta] FOREIGN KEY([id_estado_resolucion_cuenta])
REFERENCES [dbo].[Estado] ([id_estado])
GO
ALTER TABLE [dbo].[Disputa] CHECK CONSTRAINT [FK_disputa_id_estado_resolucion_cuenta]
GO
ALTER TABLE [dbo].[Disputa]  WITH CHECK ADD  CONSTRAINT [FK_disputa_id_estado_resolucion_mp] FOREIGN KEY([id_estado_resolucion_mp])
REFERENCES [dbo].[Estado] ([id_estado])
GO
ALTER TABLE [dbo].[Disputa] CHECK CONSTRAINT [FK_disputa_id_estado_resolucion_mp]
GO
ALTER TABLE [dbo].[Disputa]  WITH CHECK ADD  CONSTRAINT [FK_disputa_id_medio_pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Disputa] CHECK CONSTRAINT [FK_disputa_id_medio_pago]
GO
ALTER TABLE [dbo].[Disputa]  WITH CHECK ADD  CONSTRAINT [FK_Disputa_Id_Motivo_Estado] FOREIGN KEY([id_motivo_estado])
REFERENCES [dbo].[Motivo_Estado] ([id_motivo_estado])
GO
ALTER TABLE [dbo].[Disputa] CHECK CONSTRAINT [FK_Disputa_Id_Motivo_Estado]
GO
ALTER TABLE [dbo].[Disputa]  WITH CHECK ADD  CONSTRAINT [FK_disputa_id_tipo_origen] FOREIGN KEY([id_tipo_origen])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Disputa] CHECK CONSTRAINT [FK_disputa_id_tipo_origen]
GO
ALTER TABLE [dbo].[Disputa]  WITH CHECK ADD  CONSTRAINT [FK_Disputa_Log_Proceso] FOREIGN KEY([id_log_proceso])
REFERENCES [dbo].[Log_Proceso] ([id_log_proceso])
GO
ALTER TABLE [dbo].[Disputa] CHECK CONSTRAINT [FK_Disputa_Log_Proceso]
GO
ALTER TABLE [dbo].[Disputa]  WITH CHECK ADD  CONSTRAINT [FK_doc_disputa_id_disputa] FOREIGN KEY([id_disputa])
REFERENCES [dbo].[Disputa] ([id_disputa])
GO
ALTER TABLE [dbo].[Disputa] CHECK CONSTRAINT [FK_doc_disputa_id_disputa]
GO
ALTER TABLE [dbo].[Disputa]  WITH CHECK ADD  CONSTRAINT [FK_NotificacionEnviada_IdNotificacion] FOREIGN KEY([id_notificacion_enviada])
REFERENCES [dbo].[Notificacion_Enviada] ([id_notificacion_enviada])
GO
ALTER TABLE [dbo].[Disputa] CHECK CONSTRAINT [FK_NotificacionEnviada_IdNotificacion]
GO
ALTER TABLE [dbo].[Doc_Disputa]  WITH CHECK ADD  CONSTRAINT [FK_doc_disputa_id_documento] FOREIGN KEY([id_documento])
REFERENCES [dbo].[Documento] ([id_documento])
GO
ALTER TABLE [dbo].[Doc_Disputa] CHECK CONSTRAINT [FK_doc_disputa_id_documento]
GO
ALTER TABLE [dbo].[Doc_Situacion_Fiscal_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Doc_Situacion_Fiscal_Cue_Documento] FOREIGN KEY([id_documento])
REFERENCES [dbo].[Documento] ([id_documento])
GO
ALTER TABLE [dbo].[Doc_Situacion_Fiscal_Cuenta] CHECK CONSTRAINT [FK_Doc_Situacion_Fiscal_Cue_Documento]
GO
ALTER TABLE [dbo].[Doc_Situacion_Fiscal_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Doc_Situacion_Fiscal_Cue_Estado] FOREIGN KEY([id_estado_documento])
REFERENCES [dbo].[Estado] ([id_estado])
GO
ALTER TABLE [dbo].[Doc_Situacion_Fiscal_Cuenta] CHECK CONSTRAINT [FK_Doc_Situacion_Fiscal_Cue_Estado]
GO
ALTER TABLE [dbo].[Doc_Situacion_Fiscal_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Doc_Situacion_Fiscal_Cue_Situacion_Fiscal_Cuenta] FOREIGN KEY([id_situacion_fiscal])
REFERENCES [dbo].[Situacion_Fiscal_Cuenta] ([id_situacion_fiscal])
GO
ALTER TABLE [dbo].[Doc_Situacion_Fiscal_Cuenta] CHECK CONSTRAINT [FK_Doc_Situacion_Fiscal_Cue_Situacion_Fiscal_Cuenta]
GO
ALTER TABLE [dbo].[Doc_Situacion_Fiscal_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Doc_Situacion_Fiscal_Cuenta_Motivo_Estado] FOREIGN KEY([id_motivo_estado])
REFERENCES [dbo].[Motivo_Estado] ([id_motivo_estado])
GO
ALTER TABLE [dbo].[Doc_Situacion_Fiscal_Cuenta] CHECK CONSTRAINT [FK_Doc_Situacion_Fiscal_Cuenta_Motivo_Estado]
GO
ALTER TABLE [dbo].[Documento]  WITH NOCHECK ADD  CONSTRAINT [FK_Documento_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Documento] CHECK CONSTRAINT [FK_Documento_Cuenta]
GO
ALTER TABLE [dbo].[Documento]  WITH NOCHECK ADD  CONSTRAINT [FK_Documento_Tipo] FOREIGN KEY([id_tipo_documento])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Documento] CHECK CONSTRAINT [FK_Documento_Tipo]
GO
ALTER TABLE [dbo].[Documento_Por_Tipo]  WITH NOCHECK ADD  CONSTRAINT [FK_Documento_Por_Tipo_Tipo_id_tipo_condicion] FOREIGN KEY([id_tipo_condicion])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Documento_Por_Tipo] CHECK CONSTRAINT [FK_Documento_Por_Tipo_Tipo_id_tipo_condicion]
GO
ALTER TABLE [dbo].[Documento_Por_Tipo]  WITH NOCHECK ADD  CONSTRAINT [FK_Documento_Por_Tipo_Tipo_id_tipo_documento] FOREIGN KEY([id_tipo_documento])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Documento_Por_Tipo] CHECK CONSTRAINT [FK_Documento_Por_Tipo_Tipo_id_tipo_documento]
GO
ALTER TABLE [dbo].[Domicilio_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Domicilio_Cuenta_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Domicilio_Cuenta] CHECK CONSTRAINT [FK_Domicilio_Cuenta_Cuenta]
GO
ALTER TABLE [dbo].[Domicilio_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Domicilio_Cuenta_Localidad] FOREIGN KEY([id_localidad])
REFERENCES [dbo].[Localidad] ([id_localidad])
GO
ALTER TABLE [dbo].[Domicilio_Cuenta] CHECK CONSTRAINT [FK_Domicilio_Cuenta_Localidad]
GO
ALTER TABLE [dbo].[Domicilio_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Domicilio_Cuenta_Provincia] FOREIGN KEY([id_provincia])
REFERENCES [dbo].[Provincia] ([id_provincia])
GO
ALTER TABLE [dbo].[Domicilio_Cuenta] CHECK CONSTRAINT [FK_Domicilio_Cuenta_Provincia]
GO
ALTER TABLE [dbo].[Domicilio_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Domicilio_Cuenta_Tipo] FOREIGN KEY([id_tipo_domicilio])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Domicilio_Cuenta] CHECK CONSTRAINT [FK_Domicilio_Cuenta_Tipo]
GO
ALTER TABLE [dbo].[Estado]  WITH NOCHECK ADD  CONSTRAINT [FK_Estado_Grupo_Estado] FOREIGN KEY([id_grupo_estado])
REFERENCES [dbo].[Grupo_Estado] ([id_grupo_estado])
GO
ALTER TABLE [dbo].[Estado] CHECK CONSTRAINT [FK_Estado_Grupo_Estado]
GO
ALTER TABLE [dbo].[Estado_Movimiento_MP]  WITH NOCHECK ADD  CONSTRAINT [FK_Estado_Movimiento_MP_Medio_De_Pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Estado_Movimiento_MP] CHECK CONSTRAINT [FK_Estado_Movimiento_MP_Medio_De_Pago]
GO
ALTER TABLE [dbo].[Historico_Mail_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Historico_Mail_Cuenta_id_cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Historico_Mail_Cuenta] CHECK CONSTRAINT [FK_Historico_Mail_Cuenta_id_cuenta]
GO
ALTER TABLE [dbo].[Historico_Mail_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Historico_Mail_Cuenta_id_estado_mail] FOREIGN KEY([id_estado_mail])
REFERENCES [dbo].[Estado] ([id_estado])
GO
ALTER TABLE [dbo].[Historico_Mail_Cuenta] CHECK CONSTRAINT [FK_Historico_Mail_Cuenta_id_estado_mail]
GO
ALTER TABLE [dbo].[Impuesto]  WITH NOCHECK ADD  CONSTRAINT [FK_Impuesto_Provincia] FOREIGN KEY([id_provincia])
REFERENCES [dbo].[Provincia] ([id_provincia])
GO
ALTER TABLE [dbo].[Impuesto] CHECK CONSTRAINT [FK_Impuesto_Provincia]
GO
ALTER TABLE [dbo].[Impuesto_General_MP]  WITH NOCHECK ADD  CONSTRAINT [FK_Impuestos_generales_de_m_Log_Paso_Proceso] FOREIGN KEY([id_log_paso])
REFERENCES [dbo].[Log_Paso_Proceso] ([id_log_paso])
GO
ALTER TABLE [dbo].[Impuesto_General_MP] CHECK CONSTRAINT [FK_Impuestos_generales_de_m_Log_Paso_Proceso]
GO
ALTER TABLE [dbo].[Impuesto_General_MP]  WITH NOCHECK ADD  CONSTRAINT [FK_Impuestos_generales_de_m_Medio_De_Pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Impuesto_General_MP] CHECK CONSTRAINT [FK_Impuestos_generales_de_m_Medio_De_Pago]
GO
ALTER TABLE [dbo].[Impuesto_Por_Tipo]  WITH NOCHECK ADD  CONSTRAINT [FK_Impuesto_Por_Tipo_Tipo_id_base_de_calculo] FOREIGN KEY([id_base_de_calculo])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Impuesto_Por_Tipo] CHECK CONSTRAINT [FK_Impuesto_Por_Tipo_Tipo_id_base_de_calculo]
GO
ALTER TABLE [dbo].[Impuesto_Por_Tipo]  WITH NOCHECK ADD  CONSTRAINT [FK_Impuesto_Por_Tipo_Tipo_id_tipo] FOREIGN KEY([id_tipo])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Impuesto_Por_Tipo] CHECK CONSTRAINT [FK_Impuesto_Por_Tipo_Tipo_id_tipo]
GO
ALTER TABLE [dbo].[Impuesto_Por_Tipo]  WITH NOCHECK ADD  CONSTRAINT [FK_Impuesto_Por_Tipo_Tipo_id_tipo_aplicacion] FOREIGN KEY([id_tipo_aplicacion])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Impuesto_Por_Tipo] CHECK CONSTRAINT [FK_Impuesto_Por_Tipo_Tipo_id_tipo_aplicacion]
GO
ALTER TABLE [dbo].[Impuesto_Por_Tipo]  WITH NOCHECK ADD  CONSTRAINT [FK_ImpuestoPorTipo_Impuesto] FOREIGN KEY([id_impuesto])
REFERENCES [dbo].[Impuesto] ([id_impuesto])
GO
ALTER TABLE [dbo].[Impuesto_Por_Tipo] CHECK CONSTRAINT [FK_ImpuestoPorTipo_Impuesto]
GO
ALTER TABLE [dbo].[Inconsistencia_En_Transaccion]  WITH CHECK ADD  CONSTRAINT [FK_Inconsistencia_Log_Proceso] FOREIGN KEY([id_log_proceso])
REFERENCES [dbo].[Log_Proceso] ([id_log_proceso])
GO
ALTER TABLE [dbo].[Inconsistencia_En_Transaccion] CHECK CONSTRAINT [FK_Inconsistencia_Log_Proceso]
GO
ALTER TABLE [dbo].[Informacion_Bancaria_Cuenta]  WITH CHECK ADD FOREIGN KEY([id_moneda_cuenta_banco])
REFERENCES [dbo].[Moneda] ([id_moneda])
GO
ALTER TABLE [dbo].[Informacion_Bancaria_Cuenta]  WITH CHECK ADD FOREIGN KEY([id_tipo_cuenta_banco])
REFERENCES [dbo].[Parametro] ([id_parametro])
GO
ALTER TABLE [dbo].[Informacion_Bancaria_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_IBC_id_tipo_cashout] FOREIGN KEY([id_tipo_cashout])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Informacion_Bancaria_Cuenta] CHECK CONSTRAINT [FK_IBC_id_tipo_cashout]
GO
ALTER TABLE [dbo].[Informacion_Bancaria_Cuenta]  WITH CHECK ADD  CONSTRAINT [fk_id_canal1] FOREIGN KEY([id_canal])
REFERENCES [dbo].[Canal_Adhesion] ([id_canal])
GO
ALTER TABLE [dbo].[Informacion_Bancaria_Cuenta] CHECK CONSTRAINT [fk_id_canal1]
GO
ALTER TABLE [dbo].[Informacion_Bancaria_Cuenta]  WITH CHECK ADD  CONSTRAINT [fk_id_motivo_estado] FOREIGN KEY([id_motivo_estado])
REFERENCES [dbo].[Motivo_Estado] ([id_motivo_estado])
GO
ALTER TABLE [dbo].[Informacion_Bancaria_Cuenta] CHECK CONSTRAINT [fk_id_motivo_estado]
GO
ALTER TABLE [dbo].[Informacion_Bancaria_Cuenta]  WITH CHECK ADD  CONSTRAINT [fk_id_tipo_cashout_solicitado] FOREIGN KEY([id_tipo_cashout_solicitado])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Informacion_Bancaria_Cuenta] CHECK CONSTRAINT [fk_id_tipo_cashout_solicitado]
GO
ALTER TABLE [dbo].[Informacion_Bancaria_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Informacion_Bancaria_Cue_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Informacion_Bancaria_Cuenta] CHECK CONSTRAINT [FK_Informacion_Bancaria_Cue_Cuenta]
GO
ALTER TABLE [dbo].[Informacion_Bancaria_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_INFORMACION_BANCARIA_ESTADO] FOREIGN KEY([id_estado_informacion_bancaria])
REFERENCES [dbo].[Estado] ([id_estado])
GO
ALTER TABLE [dbo].[Informacion_Bancaria_Cuenta] CHECK CONSTRAINT [FK_INFORMACION_BANCARIA_ESTADO]
GO
ALTER TABLE [dbo].[Item_Facturacion]  WITH CHECK ADD  CONSTRAINT [FK_Item_Facturacion_Ciclo_Facturacion] FOREIGN KEY([id_ciclo_facturacion])
REFERENCES [dbo].[Ciclo_Facturacion] ([id_ciclo_facturacion])
GO
ALTER TABLE [dbo].[Item_Facturacion] CHECK CONSTRAINT [FK_Item_Facturacion_Ciclo_Facturacion]
GO
ALTER TABLE [dbo].[Item_Facturacion]  WITH CHECK ADD  CONSTRAINT [FK_Item_Facturacion_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Item_Facturacion] CHECK CONSTRAINT [FK_Item_Facturacion_Cuenta]
GO
ALTER TABLE [dbo].[Item_Facturacion]  WITH CHECK ADD  CONSTRAINT [FK_Item_Facturacion_Log_Paso_Proceso] FOREIGN KEY([id_log_facturacion])
REFERENCES [dbo].[Log_Paso_Proceso] ([id_log_paso])
GO
ALTER TABLE [dbo].[Item_Facturacion] CHECK CONSTRAINT [FK_Item_Facturacion_Log_Paso_Proceso]
GO
ALTER TABLE [dbo].[Item_Facturacion]  WITH CHECK ADD  CONSTRAINT [FK_Item_Facturacion_Log_Paso_Proceso2] FOREIGN KEY([id_log_vuelta_facturacion])
REFERENCES [dbo].[Log_Paso_Proceso] ([id_log_paso])
GO
ALTER TABLE [dbo].[Item_Facturacion] CHECK CONSTRAINT [FK_Item_Facturacion_Log_Paso_Proceso2]
GO
ALTER TABLE [dbo].[Limite]  WITH CHECK ADD  CONSTRAINT [FK_Limite_id_banco] FOREIGN KEY([id_banco])
REFERENCES [dbo].[Banco] ([id_banco])
GO
ALTER TABLE [dbo].[Limite] CHECK CONSTRAINT [FK_Limite_id_banco]
GO
ALTER TABLE [dbo].[Limite]  WITH CHECK ADD  CONSTRAINT [FK_Limite_id_nivel_riesgo_mp] FOREIGN KEY([id_nivel_riesgo_mp])
REFERENCES [dbo].[Nivel_Riesgo_MP] ([id_nivel_riesgo])
GO
ALTER TABLE [dbo].[Limite] CHECK CONSTRAINT [FK_Limite_id_nivel_riesgo_mp]
GO
ALTER TABLE [dbo].[Limite]  WITH CHECK ADD  CONSTRAINT [FK_Limite_id_tipo_identificacion] FOREIGN KEY([id_tipo_identificacion])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Limite] CHECK CONSTRAINT [FK_Limite_id_tipo_identificacion]
GO
ALTER TABLE [dbo].[Limite]  WITH CHECK ADD  CONSTRAINT [FK_Limite_id_tipo_medio_pago] FOREIGN KEY([id_tipo_medio_pago])
REFERENCES [dbo].[Tipo_Medio_Pago] ([id_tipo_medio_pago])
GO
ALTER TABLE [dbo].[Limite] CHECK CONSTRAINT [FK_Limite_id_tipo_medio_pago]
GO
ALTER TABLE [dbo].[Limite]  WITH NOCHECK ADD  CONSTRAINT [FK_Limite_Tipo_id_cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Limite] CHECK CONSTRAINT [FK_Limite_Tipo_id_cuenta]
GO
ALTER TABLE [dbo].[Limite]  WITH NOCHECK ADD  CONSTRAINT [FK_Limite_Tipo_id_rubro] FOREIGN KEY([id_rubro])
REFERENCES [dbo].[Rubro] ([id_rubro])
GO
ALTER TABLE [dbo].[Limite] CHECK CONSTRAINT [FK_Limite_Tipo_id_rubro]
GO
ALTER TABLE [dbo].[Limite]  WITH NOCHECK ADD  CONSTRAINT [FK_Limite_Tipo_id_tipo_accion_limite] FOREIGN KEY([id_tipo_accion_limite])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Limite] CHECK CONSTRAINT [FK_Limite_Tipo_id_tipo_accion_limite]
GO
ALTER TABLE [dbo].[Limite]  WITH NOCHECK ADD  CONSTRAINT [FK_Limite_Tipo_id_tipo_aplicacion_limite] FOREIGN KEY([id_tipo_aplicacion_limite])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Limite] CHECK CONSTRAINT [FK_Limite_Tipo_id_tipo_aplicacion_limite]
GO
ALTER TABLE [dbo].[Limite]  WITH NOCHECK ADD  CONSTRAINT [FK_Limite_Tipo_id_tipo_condicion_IVA] FOREIGN KEY([id_tipo_condicion_IVA])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Limite] CHECK CONSTRAINT [FK_Limite_Tipo_id_tipo_condicion_IVA]
GO
ALTER TABLE [dbo].[Limite]  WITH NOCHECK ADD  CONSTRAINT [FK_Limite_Tipo_id_tipo_cuenta] FOREIGN KEY([id_tipo_cuenta])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Limite] CHECK CONSTRAINT [FK_Limite_Tipo_id_tipo_cuenta]
GO
ALTER TABLE [dbo].[Limite]  WITH NOCHECK ADD  CONSTRAINT [FK_Limite_Tipo_id_tipo_limite] FOREIGN KEY([id_tipo_limite])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Limite] CHECK CONSTRAINT [FK_Limite_Tipo_id_tipo_limite]
GO
ALTER TABLE [dbo].[Lista_Negra_Identificacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Lista_Negra_Identificacion_Tipo] FOREIGN KEY([id_tipo_identificacion])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Lista_Negra_Identificacion] CHECK CONSTRAINT [FK_Lista_Negra_Identificacion_Tipo]
GO
ALTER TABLE [dbo].[Localidad]  WITH NOCHECK ADD  CONSTRAINT [FK_Localidad_Provincia] FOREIGN KEY([id_provincia])
REFERENCES [dbo].[Provincia] ([id_provincia])
GO
ALTER TABLE [dbo].[Localidad] CHECK CONSTRAINT [FK_Localidad_Provincia]
GO
ALTER TABLE [dbo].[Log_Movimiento_Cuenta_Virtual]  WITH NOCHECK ADD  CONSTRAINT [FK_Log_Movimiento_Cuenta_Vi_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Log_Movimiento_Cuenta_Virtual] CHECK CONSTRAINT [FK_Log_Movimiento_Cuenta_Vi_Cuenta]
GO
ALTER TABLE [dbo].[Log_Movimiento_Cuenta_Virtual]  WITH NOCHECK ADD  CONSTRAINT [FK_Log_Movimiento_Cuenta_Vi_Log_Proceso] FOREIGN KEY([id_log_proceso])
REFERENCES [dbo].[Log_Proceso] ([id_log_proceso])
GO
ALTER TABLE [dbo].[Log_Movimiento_Cuenta_Virtual] CHECK CONSTRAINT [FK_Log_Movimiento_Cuenta_Vi_Log_Proceso]
GO
ALTER TABLE [dbo].[Log_Movimiento_Cuenta_Virtual]  WITH NOCHECK ADD  CONSTRAINT [FK_Log_Movimiento_Cuenta_Vi_Tipo_id_tipo_movimiento] FOREIGN KEY([id_tipo_movimiento])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Log_Movimiento_Cuenta_Virtual] CHECK CONSTRAINT [FK_Log_Movimiento_Cuenta_Vi_Tipo_id_tipo_movimiento]
GO
ALTER TABLE [dbo].[Log_Movimiento_Cuenta_Virtual]  WITH NOCHECK ADD  CONSTRAINT [FK_Log_Movimiento_Cuenta_Vi_Tipo_id_tipo_origen_movimiento] FOREIGN KEY([id_tipo_origen_movimiento])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Log_Movimiento_Cuenta_Virtual] CHECK CONSTRAINT [FK_Log_Movimiento_Cuenta_Vi_Tipo_id_tipo_origen_movimiento]
GO
ALTER TABLE [dbo].[Log_Movimiento_Cuenta_Virtual]  WITH CHECK ADD  CONSTRAINT [FK_Log_Movimiento_Cuenta_Virtual_Canal_Adhesion] FOREIGN KEY([id_canal])
REFERENCES [dbo].[Canal_Adhesion] ([id_canal])
GO
ALTER TABLE [dbo].[Log_Movimiento_Cuenta_Virtual] CHECK CONSTRAINT [FK_Log_Movimiento_Cuenta_Virtual_Canal_Adhesion]
GO
ALTER TABLE [dbo].[Log_Paso_Proceso]  WITH NOCHECK ADD  CONSTRAINT [FK_Log_Paso_Proceso_Log_Proceso] FOREIGN KEY([id_log_proceso])
REFERENCES [dbo].[Log_Proceso] ([id_log_proceso])
GO
ALTER TABLE [dbo].[Log_Paso_Proceso] CHECK CONSTRAINT [FK_Log_Paso_Proceso_Log_Proceso]
GO
ALTER TABLE [dbo].[Log_Paso_Proceso]  WITH NOCHECK ADD  CONSTRAINT [FK_Log_Paso_Proceso_Paso_Proceso] FOREIGN KEY([id_paso_proceso])
REFERENCES [dbo].[Paso_Proceso] ([id_paso_proceso])
GO
ALTER TABLE [dbo].[Log_Paso_Proceso] CHECK CONSTRAINT [FK_Log_Paso_Proceso_Paso_Proceso]
GO
ALTER TABLE [dbo].[Log_Proceso]  WITH NOCHECK ADD  CONSTRAINT [FK_Log_Proceso_Proceso] FOREIGN KEY([id_proceso])
REFERENCES [dbo].[Proceso] ([id_proceso])
GO
ALTER TABLE [dbo].[Log_Proceso] CHECK CONSTRAINT [FK_Log_Proceso_Proceso]
GO
ALTER TABLE [dbo].[Log_Registracion_CBU]  WITH CHECK ADD  CONSTRAINT [fk_id_informacion_bancaria_cuenta] FOREIGN KEY([id_informacion_bancaria_cuenta])
REFERENCES [dbo].[Informacion_Bancaria_Cuenta] ([id_informacion_bancaria])
GO
ALTER TABLE [dbo].[Log_Registracion_CBU] CHECK CONSTRAINT [fk_id_informacion_bancaria_cuenta]
GO
ALTER TABLE [dbo].[Mail_Grupo_Notificacion_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Mail_Grupo_Notificacion__Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Mail_Grupo_Notificacion_Cuenta] CHECK CONSTRAINT [FK_Mail_Grupo_Notificacion__Cuenta]
GO
ALTER TABLE [dbo].[Mail_Grupo_Notificacion_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Mail_Grupo_Notificacion__Grupo_Notificacion] FOREIGN KEY([id_grupo_notificacion])
REFERENCES [dbo].[Grupo_Notificacion] ([id_grupo_notificacion])
GO
ALTER TABLE [dbo].[Mail_Grupo_Notificacion_Cuenta] CHECK CONSTRAINT [FK_Mail_Grupo_Notificacion__Grupo_Notificacion]
GO
ALTER TABLE [dbo].[Mail_Notificacion]  WITH CHECK ADD  CONSTRAINT [FK_Mail_Notificacion_Notificacion] FOREIGN KEY([id_notificacion])
REFERENCES [dbo].[Notificacion] ([id_notificacion])
GO
ALTER TABLE [dbo].[Mail_Notificacion] CHECK CONSTRAINT [FK_Mail_Notificacion_Notificacion]
GO
ALTER TABLE [dbo].[Medio_De_Pago]  WITH CHECK ADD  CONSTRAINT [FK_Medio_De_Pago_Resolutor] FOREIGN KEY([id_resolutor])
REFERENCES [dbo].[Resolutor_Transaccion] ([id_resolutor])
GO
ALTER TABLE [dbo].[Medio_De_Pago] CHECK CONSTRAINT [FK_Medio_De_Pago_Resolutor]
GO
ALTER TABLE [dbo].[Medio_De_Pago]  WITH NOCHECK ADD  CONSTRAINT [FK_Medio_De_Pago_Tipo_Medio_Pago] FOREIGN KEY([id_tipo_medio_pago])
REFERENCES [dbo].[Tipo_Medio_Pago] ([id_tipo_medio_pago])
GO
ALTER TABLE [dbo].[Medio_De_Pago] CHECK CONSTRAINT [FK_Medio_De_Pago_Tipo_Medio_Pago]
GO
ALTER TABLE [dbo].[Medio_Pago_Banco]  WITH NOCHECK ADD  CONSTRAINT [FK_Medio_Pago_Banco_Banco] FOREIGN KEY([id_banco])
REFERENCES [dbo].[Banco] ([id_banco])
GO
ALTER TABLE [dbo].[Medio_Pago_Banco] CHECK CONSTRAINT [FK_Medio_Pago_Banco_Banco]
GO
ALTER TABLE [dbo].[Medio_Pago_Banco]  WITH NOCHECK ADD  CONSTRAINT [FK_Medio_Pago_Banco_Medio_de_Pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Medio_Pago_Banco] CHECK CONSTRAINT [FK_Medio_Pago_Banco_Medio_de_Pago]
GO
ALTER TABLE [dbo].[Medio_Pago_Boton]  WITH NOCHECK ADD  CONSTRAINT [FK_Medio_Pago_Boton_Boton] FOREIGN KEY([id_boton])
REFERENCES [dbo].[Boton] ([id_boton])
GO
ALTER TABLE [dbo].[Medio_Pago_Boton] CHECK CONSTRAINT [FK_Medio_Pago_Boton_Boton]
GO
ALTER TABLE [dbo].[Medio_Pago_Boton]  WITH NOCHECK ADD  CONSTRAINT [FK_Medio_Pago_Boton_Medio_De_Pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Medio_Pago_Boton] CHECK CONSTRAINT [FK_Medio_Pago_Boton_Medio_De_Pago]
GO
ALTER TABLE [dbo].[Medio_Pago_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Medio_Pago_Cuenta_id_banco] FOREIGN KEY([id_banco])
REFERENCES [dbo].[Banco] ([id_banco])
GO
ALTER TABLE [dbo].[Medio_Pago_Cuenta] CHECK CONSTRAINT [FK_Medio_Pago_Cuenta_id_banco]
GO
ALTER TABLE [dbo].[Medio_Pago_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Medio_Pago_Cuenta_id_cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Medio_Pago_Cuenta] CHECK CONSTRAINT [FK_Medio_Pago_Cuenta_id_cuenta]
GO
ALTER TABLE [dbo].[Medio_Pago_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Medio_Pago_Cuenta_id_estado_medio_pago] FOREIGN KEY([id_estado_medio_pago])
REFERENCES [dbo].[Estado] ([id_estado])
GO
ALTER TABLE [dbo].[Medio_Pago_Cuenta] CHECK CONSTRAINT [FK_Medio_Pago_Cuenta_id_estado_medio_pago]
GO
ALTER TABLE [dbo].[Medio_Pago_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Medio_Pago_Cuenta_id_medio_pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Medio_Pago_Cuenta] CHECK CONSTRAINT [FK_Medio_Pago_Cuenta_id_medio_pago]
GO
ALTER TABLE [dbo].[Medio_Pago_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_MPC_tipo_medio_pago] FOREIGN KEY([id_tipo_medio_pago])
REFERENCES [dbo].[Tipo_Medio_Pago] ([id_tipo_medio_pago])
GO
ALTER TABLE [dbo].[Medio_Pago_Cuenta] CHECK CONSTRAINT [FK_MPC_tipo_medio_pago]
GO
ALTER TABLE [dbo].[Medio_Pago_Transaccion]  WITH CHECK ADD  CONSTRAINT [FK_Medio_Pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Medio_Pago_Transaccion] CHECK CONSTRAINT [FK_Medio_Pago]
GO
ALTER TABLE [dbo].[Moneda_Medio_Pago]  WITH NOCHECK ADD  CONSTRAINT [FK_Moneda_Medio_Pago_Medio_De_Pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Moneda_Medio_Pago] CHECK CONSTRAINT [FK_Moneda_Medio_Pago_Medio_De_Pago]
GO
ALTER TABLE [dbo].[Moneda_Medio_Pago]  WITH NOCHECK ADD  CONSTRAINT [FK_Moneda_Medio_Pago_Moneda] FOREIGN KEY([id_moneda])
REFERENCES [dbo].[Moneda] ([id_moneda])
GO
ALTER TABLE [dbo].[Moneda_Medio_Pago] CHECK CONSTRAINT [FK_Moneda_Medio_Pago_Moneda]
GO
ALTER TABLE [dbo].[Motivo]  WITH CHECK ADD  CONSTRAINT [FK_GRUPO_MOTIVO_ID_GRUPO_MOTIVO] FOREIGN KEY([id_grupo_motivo])
REFERENCES [dbo].[Grupo_Motivo] ([id_grupo_motivo])
GO
ALTER TABLE [dbo].[Motivo] CHECK CONSTRAINT [FK_GRUPO_MOTIVO_ID_GRUPO_MOTIVO]
GO
ALTER TABLE [dbo].[Motivo_Estado]  WITH NOCHECK ADD  CONSTRAINT [FK_Motivo_Estado_Estado] FOREIGN KEY([id_estado])
REFERENCES [dbo].[Estado] ([id_estado])
GO
ALTER TABLE [dbo].[Motivo_Estado] CHECK CONSTRAINT [FK_Motivo_Estado_Estado]
GO
ALTER TABLE [dbo].[Movimiento_Presentado_MP]  WITH NOCHECK ADD  CONSTRAINT [FK_Movimientos_a_conciliar_Medio_De_Pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Movimiento_Presentado_MP] CHECK CONSTRAINT [FK_Movimientos_a_conciliar_Medio_De_Pago]
GO
ALTER TABLE [dbo].[Movimiento_Presentado_MP]  WITH NOCHECK ADD  CONSTRAINT [FK_MPMP_codigo_operacion] FOREIGN KEY([id_codigo_operacion])
REFERENCES [dbo].[Codigo_Operacion] ([id_codigo_operacion])
GO
ALTER TABLE [dbo].[Movimiento_Presentado_MP] CHECK CONSTRAINT [FK_MPMP_codigo_operacion]
GO
ALTER TABLE [dbo].[Movimientos_a_distribuir]  WITH CHECK ADD  CONSTRAINT [FK_MaD_Mov_Pres_MP] FOREIGN KEY([id_movimiento_mp])
REFERENCES [dbo].[Movimiento_Presentado_MP] ([id_movimiento_mp])
GO
ALTER TABLE [dbo].[Movimientos_a_distribuir] CHECK CONSTRAINT [FK_MaD_Mov_Pres_MP]
GO
ALTER TABLE [dbo].[Movimientos_a_distribuir]  WITH NOCHECK ADD  CONSTRAINT [FK_TMP_Movimientos_A_Distribuir_Medio_de_pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Movimientos_a_distribuir] CHECK CONSTRAINT [FK_TMP_Movimientos_A_Distribuir_Medio_de_pago]
GO
ALTER TABLE [dbo].[Notificacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Notificacion_Grupo_Notificacion] FOREIGN KEY([id_grupo_notificacion])
REFERENCES [dbo].[Grupo_Notificacion] ([id_grupo_notificacion])
GO
ALTER TABLE [dbo].[Notificacion] CHECK CONSTRAINT [FK_Notificacion_Grupo_Notificacion]
GO
ALTER TABLE [dbo].[Notificacion_Enviada]  WITH NOCHECK ADD  CONSTRAINT [FK_Notificacion_Enviada_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Notificacion_Enviada] CHECK CONSTRAINT [FK_Notificacion_Enviada_Cuenta]
GO
ALTER TABLE [dbo].[Notificacion_Enviada]  WITH CHECK ADD  CONSTRAINT [FK_Notificacion_Enviada_Notificacion] FOREIGN KEY([id_notificacion])
REFERENCES [dbo].[Notificacion] ([id_notificacion])
GO
ALTER TABLE [dbo].[Notificacion_Enviada] CHECK CONSTRAINT [FK_Notificacion_Enviada_Notificacion]
GO
ALTER TABLE [dbo].[Notificacion_Recibida]  WITH NOCHECK ADD  CONSTRAINT [FK_Notificacion_Recibida_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Notificacion_Recibida] CHECK CONSTRAINT [FK_Notificacion_Recibida_Cuenta]
GO
ALTER TABLE [dbo].[Notificacion_Recibida]  WITH CHECK ADD  CONSTRAINT [FK_Notificacion_Recibida_Notificacion] FOREIGN KEY([id_notificacion])
REFERENCES [dbo].[Notificacion] ([id_notificacion])
GO
ALTER TABLE [dbo].[Notificacion_Recibida] CHECK CONSTRAINT [FK_Notificacion_Recibida_Notificacion]
GO
ALTER TABLE [dbo].[Operatoria_MP_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Operatoria_MP_Cuenta_id_cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Operatoria_MP_Cuenta] CHECK CONSTRAINT [FK_Operatoria_MP_Cuenta_id_cuenta]
GO
ALTER TABLE [dbo].[Operatoria_MP_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Operatoria_MP_Cuenta_id_medio_pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Operatoria_MP_Cuenta] CHECK CONSTRAINT [FK_Operatoria_MP_Cuenta_id_medio_pago]
GO
ALTER TABLE [dbo].[Parametro]  WITH NOCHECK ADD  CONSTRAINT [FK_Parametro_Tipo_Parametro] FOREIGN KEY([id_tipo_parametro])
REFERENCES [dbo].[Tipo_Parametro] ([id_tipo_parametro])
GO
ALTER TABLE [dbo].[Parametro] CHECK CONSTRAINT [FK_Parametro_Tipo_Parametro]
GO
ALTER TABLE [dbo].[Parametro_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Parametro_Cuenta_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Parametro_Cuenta] CHECK CONSTRAINT [FK_Parametro_Cuenta_Cuenta]
GO
ALTER TABLE [dbo].[Paso_Proceso]  WITH NOCHECK ADD  CONSTRAINT [FK_Paso_Proceso_Proceso] FOREIGN KEY([id_proceso])
REFERENCES [dbo].[Proceso] ([id_proceso])
GO
ALTER TABLE [dbo].[Paso_Proceso] CHECK CONSTRAINT [FK_Paso_Proceso_Proceso]
GO
ALTER TABLE [dbo].[Plan]  WITH NOCHECK ADD  CONSTRAINT [FK_Plan_Medio_De_Pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Plan] CHECK CONSTRAINT [FK_Plan_Medio_De_Pago]
GO
ALTER TABLE [dbo].[Plazo_Liberacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Plazo_Liberacion_Tipo_Medio_Pago_id_cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Plazo_Liberacion] CHECK CONSTRAINT [FK_Plazo_Liberacion_Tipo_Medio_Pago_id_cuenta]
GO
ALTER TABLE [dbo].[Plazo_Liberacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Plazo_Liberacion_Tipo_Medio_Pago_id_rubro] FOREIGN KEY([id_tipo_medio_pago])
REFERENCES [dbo].[Tipo_Medio_Pago] ([id_tipo_medio_pago])
GO
ALTER TABLE [dbo].[Plazo_Liberacion] CHECK CONSTRAINT [FK_Plazo_Liberacion_Tipo_Medio_Pago_id_rubro]
GO
ALTER TABLE [dbo].[Plazo_Liberacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Plazo_Liberacion_Tipo_Medio_Pago_id_tipo_medio_pago] FOREIGN KEY([id_rubro])
REFERENCES [dbo].[Tipo_Medio_Pago] ([id_tipo_medio_pago])
GO
ALTER TABLE [dbo].[Plazo_Liberacion] CHECK CONSTRAINT [FK_Plazo_Liberacion_Tipo_Medio_Pago_id_tipo_medio_pago]
GO
ALTER TABLE [dbo].[Primera_Vez_Banco_Cuenta]  WITH CHECK ADD  CONSTRAINT [fk_id_banco] FOREIGN KEY([id_banco])
REFERENCES [dbo].[Banco] ([id_banco])
GO
ALTER TABLE [dbo].[Primera_Vez_Banco_Cuenta] CHECK CONSTRAINT [fk_id_banco]
GO
ALTER TABLE [dbo].[Primera_Vez_Banco_Cuenta]  WITH CHECK ADD  CONSTRAINT [fk_id_cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Primera_Vez_Banco_Cuenta] CHECK CONSTRAINT [fk_id_cuenta]
GO
ALTER TABLE [dbo].[Proceso]  WITH NOCHECK ADD  CONSTRAINT [FK_Proceso_Tipo] FOREIGN KEY([id_tipo_frecuencia])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Proceso] CHECK CONSTRAINT [FK_Proceso_Tipo]
GO
ALTER TABLE [dbo].[Promocion]  WITH CHECK ADD  CONSTRAINT [FK_Promocion_estado_procesamiento] FOREIGN KEY([id_estado_procesamiento])
REFERENCES [dbo].[Estado] ([id_estado])
GO
ALTER TABLE [dbo].[Promocion] CHECK CONSTRAINT [FK_Promocion_estado_procesamiento]
GO
ALTER TABLE [dbo].[Promocion]  WITH CHECK ADD  CONSTRAINT [FK_Promocion_id_banco] FOREIGN KEY([id_banco])
REFERENCES [dbo].[Banco] ([id_banco])
GO
ALTER TABLE [dbo].[Promocion] CHECK CONSTRAINT [FK_Promocion_id_banco]
GO
ALTER TABLE [dbo].[Promocion]  WITH CHECK ADD  CONSTRAINT [FK_Promocion_id_cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Promocion] CHECK CONSTRAINT [FK_Promocion_id_cuenta]
GO
ALTER TABLE [dbo].[Promocion]  WITH CHECK ADD  CONSTRAINT [FK_Promocion_id_medio_pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Promocion] CHECK CONSTRAINT [FK_Promocion_id_medio_pago]
GO
ALTER TABLE [dbo].[Promocion]  WITH CHECK ADD  CONSTRAINT [FK_Promocion_id_rubro] FOREIGN KEY([id_rubro])
REFERENCES [dbo].[Rubro] ([id_rubro])
GO
ALTER TABLE [dbo].[Promocion] CHECK CONSTRAINT [FK_Promocion_id_rubro]
GO
ALTER TABLE [dbo].[Promocion]  WITH CHECK ADD  CONSTRAINT [FK_Promocion_id_tipo_aplicacion] FOREIGN KEY([id_tipo_aplicacion])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Promocion] CHECK CONSTRAINT [FK_Promocion_id_tipo_aplicacion]
GO
ALTER TABLE [dbo].[Promocion]  WITH CHECK ADD  CONSTRAINT [FK_Promocion_motivo_estado] FOREIGN KEY([id_motivo_estado])
REFERENCES [dbo].[Motivo_Estado] ([id_motivo_estado])
GO
ALTER TABLE [dbo].[Promocion] CHECK CONSTRAINT [FK_Promocion_motivo_estado]
GO
ALTER TABLE [dbo].[Promocion_Medio_Pago_Banco]  WITH NOCHECK ADD  CONSTRAINT [FK_Promocion_Medio_Pago_Banco_Banco] FOREIGN KEY([id_banco])
REFERENCES [dbo].[Banco] ([id_banco])
GO
ALTER TABLE [dbo].[Promocion_Medio_Pago_Banco] CHECK CONSTRAINT [FK_Promocion_Medio_Pago_Banco_Banco]
GO
ALTER TABLE [dbo].[Promocion_Medio_Pago_Banco]  WITH NOCHECK ADD  CONSTRAINT [FK_Promocion_Medio_Pago_Banco_Promocion_Medio_Pago] FOREIGN KEY([id_promocion_mp])
REFERENCES [dbo].[Promocion_Medio_Pago] ([id_promocion_mp])
GO
ALTER TABLE [dbo].[Promocion_Medio_Pago_Banco] CHECK CONSTRAINT [FK_Promocion_Medio_Pago_Banco_Promocion_Medio_Pago]
GO
ALTER TABLE [dbo].[Rango_BIN]  WITH NOCHECK ADD  CONSTRAINT [FK_Rango_BIN_Medio_De_Pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Rango_BIN] CHECK CONSTRAINT [FK_Rango_BIN_Medio_De_Pago]
GO
ALTER TABLE [dbo].[Regla_Bonificacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Regla_Bonificacion_Banco] FOREIGN KEY([id_banco])
REFERENCES [dbo].[Banco] ([id_banco])
GO
ALTER TABLE [dbo].[Regla_Bonificacion] CHECK CONSTRAINT [FK_Regla_Bonificacion_Banco]
GO
ALTER TABLE [dbo].[Regla_Bonificacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Regla_Bonificacion_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Regla_Bonificacion] CHECK CONSTRAINT [FK_Regla_Bonificacion_Cuenta]
GO
ALTER TABLE [dbo].[Regla_Bonificacion]  WITH CHECK ADD  CONSTRAINT [FK_Regla_Bonificacion_id_regla_promocion] FOREIGN KEY([id_regla_promocion])
REFERENCES [dbo].[Regla_Promocion] ([id_regla_promocion])
GO
ALTER TABLE [dbo].[Regla_Bonificacion] CHECK CONSTRAINT [FK_Regla_Bonificacion_id_regla_promocion]
GO
ALTER TABLE [dbo].[Regla_Bonificacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Regla_Bonificacion_Promocion] FOREIGN KEY([id_promocion])
REFERENCES [dbo].[Promocion] ([id_promocion])
GO
ALTER TABLE [dbo].[Regla_Bonificacion] CHECK CONSTRAINT [FK_Regla_Bonificacion_Promocion]
GO
ALTER TABLE [dbo].[Regla_Bonificacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Regla_Bonificacion_Tasa_MP] FOREIGN KEY([id_tasa_mp])
REFERENCES [dbo].[Tasa_MP] ([id_tasa_mp])
GO
ALTER TABLE [dbo].[Regla_Bonificacion] CHECK CONSTRAINT [FK_Regla_Bonificacion_Tasa_MP]
GO
ALTER TABLE [dbo].[Regla_Bonificacion]  WITH CHECK ADD  CONSTRAINT [FK_Regla_Promocion_id_rubro] FOREIGN KEY([id_rubro])
REFERENCES [dbo].[Rubro] ([id_rubro])
GO
ALTER TABLE [dbo].[Regla_Bonificacion] CHECK CONSTRAINT [FK_Regla_Promocion_id_rubro]
GO
ALTER TABLE [dbo].[Regla_Operacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Regla_Operacion_Tipo] FOREIGN KEY([id_tipo_regla_operacion])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Regla_Operacion] CHECK CONSTRAINT [FK_Regla_Operacion_Tipo]
GO
ALTER TABLE [dbo].[Regla_Operacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Tipo_Liberacion_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Regla_Operacion] CHECK CONSTRAINT [FK_Tipo_Liberacion_Cuenta]
GO
ALTER TABLE [dbo].[Regla_Operacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Tipo_Liberacion_Rubro] FOREIGN KEY([id_rubro])
REFERENCES [dbo].[Rubro] ([id_rubro])
GO
ALTER TABLE [dbo].[Regla_Operacion] CHECK CONSTRAINT [FK_Tipo_Liberacion_Rubro]
GO
ALTER TABLE [dbo].[Regla_Operacion]  WITH NOCHECK ADD  CONSTRAINT [FK_Tipo_Liberacion_Tipo] FOREIGN KEY([id_tipo_cuenta])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Regla_Operacion] CHECK CONSTRAINT [FK_Tipo_Liberacion_Tipo]
GO
ALTER TABLE [dbo].[Regla_Promocion]  WITH CHECK ADD  CONSTRAINT [FK_Regla_Promocion_id_promocion] FOREIGN KEY([id_promocion])
REFERENCES [dbo].[Promocion] ([id_promocion])
GO
ALTER TABLE [dbo].[Regla_Promocion] CHECK CONSTRAINT [FK_Regla_Promocion_id_promocion]
GO
ALTER TABLE [dbo].[Retiro_Dinero]  WITH NOCHECK ADD  CONSTRAINT [FK_Retiro_Dinero_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Retiro_Dinero] CHECK CONSTRAINT [FK_Retiro_Dinero_Cuenta]
GO
ALTER TABLE [dbo].[Retiro_Dinero]  WITH NOCHECK ADD  CONSTRAINT [FK_Retiro_Dinero_Informacion_Bancaria_Cuenta] FOREIGN KEY([id_informacion_bancaria_destino])
REFERENCES [dbo].[Informacion_Bancaria_Cuenta] ([id_informacion_bancaria])
GO
ALTER TABLE [dbo].[Retiro_Dinero] CHECK CONSTRAINT [FK_Retiro_Dinero_Informacion_Bancaria_Cuenta]
GO
ALTER TABLE [dbo].[Site_Transaccion]  WITH CHECK ADD  CONSTRAINT [fk_id_canal] FOREIGN KEY([id_canal])
REFERENCES [dbo].[Canal_Adhesion] ([id_canal])
GO
ALTER TABLE [dbo].[Site_Transaccion] CHECK CONSTRAINT [fk_id_canal]
GO
ALTER TABLE [dbo].[Site_Transaccion]  WITH CHECK ADD  CONSTRAINT [fk_id_tipo_concepto_boton] FOREIGN KEY([id_tipo_concepto_boton])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Site_Transaccion] CHECK CONSTRAINT [fk_id_tipo_concepto_boton]
GO
ALTER TABLE [dbo].[Site_Transaccion]  WITH CHECK ADD  CONSTRAINT [fk_id_vertical_cs] FOREIGN KEY([id_vertical_cs])
REFERENCES [dbo].[Vertical_Cybersource] ([id_vertical_CS])
GO
ALTER TABLE [dbo].[Site_Transaccion] CHECK CONSTRAINT [fk_id_vertical_cs]
GO
ALTER TABLE [dbo].[Situacion_Fiscal_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Situacion_Fiscal_Cuenta_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Situacion_Fiscal_Cuenta] CHECK CONSTRAINT [FK_Situacion_Fiscal_Cuenta_Cuenta]
GO
ALTER TABLE [dbo].[Situacion_Fiscal_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Situacion_Fiscal_Cuenta_Domicilio_Cuenta] FOREIGN KEY([id_domicilio_facturacion])
REFERENCES [dbo].[Domicilio_Cuenta] ([id_domicilio])
GO
ALTER TABLE [dbo].[Situacion_Fiscal_Cuenta] CHECK CONSTRAINT [FK_Situacion_Fiscal_Cuenta_Domicilio_Cuenta]
GO
ALTER TABLE [dbo].[Situacion_Fiscal_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Situacion_Fiscal_Cuenta_Estado] FOREIGN KEY([id_estado_documentacion])
REFERENCES [dbo].[Estado] ([id_estado])
GO
ALTER TABLE [dbo].[Situacion_Fiscal_Cuenta] CHECK CONSTRAINT [FK_Situacion_Fiscal_Cuenta_Estado]
GO
ALTER TABLE [dbo].[Situacion_Fiscal_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Situacion_Fiscal_Cuenta_Motivo_Estado] FOREIGN KEY([id_motivo_estado])
REFERENCES [dbo].[Motivo_Estado] ([id_motivo_estado])
GO
ALTER TABLE [dbo].[Situacion_Fiscal_Cuenta] CHECK CONSTRAINT [FK_Situacion_Fiscal_Cuenta_Motivo_Estado]
GO
ALTER TABLE [dbo].[Situacion_Fiscal_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Situacion_Fiscal_Cuenta_Tipo_id_tipo_condicion_IIBB] FOREIGN KEY([id_tipo_condicion_IIBB])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Situacion_Fiscal_Cuenta] CHECK CONSTRAINT [FK_Situacion_Fiscal_Cuenta_Tipo_id_tipo_condicion_IIBB]
GO
ALTER TABLE [dbo].[Situacion_Fiscal_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Situacion_Fiscal_Cuenta_Tipo_id_tipo_condicion_IVA] FOREIGN KEY([id_tipo_condicion_IVA])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Situacion_Fiscal_Cuenta] CHECK CONSTRAINT [FK_Situacion_Fiscal_Cuenta_Tipo_id_tipo_condicion_IVA]
GO
ALTER TABLE [dbo].[Tasa_MP]  WITH NOCHECK ADD  CONSTRAINT [FK_Tasa_MP_Medio_De_Pago] FOREIGN KEY([id_medio_pago])
REFERENCES [dbo].[Medio_De_Pago] ([id_medio_pago])
GO
ALTER TABLE [dbo].[Tasa_MP] CHECK CONSTRAINT [FK_Tasa_MP_Medio_De_Pago]
GO
ALTER TABLE [dbo].[Tipo]  WITH NOCHECK ADD  CONSTRAINT [FK_Tipo_Grupo_Tipo] FOREIGN KEY([id_grupo_tipo])
REFERENCES [dbo].[Grupo_Tipo] ([id_grupo_tipo])
GO
ALTER TABLE [dbo].[Tipo] CHECK CONSTRAINT [FK_Tipo_Grupo_Tipo]
GO
ALTER TABLE [dbo].[Tipo_Dato_Pendiente_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Tipo_Dato_Pendiente_Cuenta_id_tipo_cambio] FOREIGN KEY([id_tipo_cambio])
REFERENCES [dbo].[Tipo_Cambio_Pendiente] ([id_tipo_cambio])
GO
ALTER TABLE [dbo].[Tipo_Dato_Pendiente_Cuenta] CHECK CONSTRAINT [FK_Tipo_Dato_Pendiente_Cuenta_id_tipo_cambio]
GO
ALTER TABLE [dbo].[Tipo_Dato_Pendiente_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Tipo_Dato_Pendiente_Cuenta_id_tipo_cuenta] FOREIGN KEY([id_tipo_cuenta])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Tipo_Dato_Pendiente_Cuenta] CHECK CONSTRAINT [FK_Tipo_Dato_Pendiente_Cuenta_id_tipo_cuenta]
GO
ALTER TABLE [dbo].[Tipo_Medio_Pago]  WITH NOCHECK ADD  CONSTRAINT [FK_Tipo_Medio_Pago_Tipo] FOREIGN KEY([id_tipo_acreditacion])
REFERENCES [dbo].[Tipo] ([id_tipo])
GO
ALTER TABLE [dbo].[Tipo_Medio_Pago] CHECK CONSTRAINT [FK_Tipo_Medio_Pago_Tipo]
GO
ALTER TABLE [dbo].[Usuario_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Usuario_Cuenta_Cuenta] FOREIGN KEY([id_cuenta])
REFERENCES [dbo].[Cuenta] ([id_cuenta])
GO
ALTER TABLE [dbo].[Usuario_Cuenta] CHECK CONSTRAINT [FK_Usuario_Cuenta_Cuenta]
GO
ALTER TABLE [dbo].[Usuario_Cuenta]  WITH CHECK ADD  CONSTRAINT [FK_Usuario_Cuenta_id_estado_mail] FOREIGN KEY([id_estado_mail])
REFERENCES [dbo].[Estado] ([id_estado])
GO
ALTER TABLE [dbo].[Usuario_Cuenta] CHECK CONSTRAINT [FK_Usuario_Cuenta_id_estado_mail]
GO
ALTER TABLE [dbo].[Usuario_Cuenta]  WITH NOCHECK ADD  CONSTRAINT [FK_Usuario_Cuenta_Pregunta_Seguridad] FOREIGN KEY([id_pregunta_seguridad])
REFERENCES [dbo].[Pregunta_Seguridad] ([id_pregunta_seguridad])
GO
ALTER TABLE [dbo].[Usuario_Cuenta] CHECK CONSTRAINT [FK_Usuario_Cuenta_Pregunta_Seguridad]
GO
ALTER TABLE [dbo].[volumen_regla_promocion]  WITH CHECK ADD  CONSTRAINT [FK_Volumen_Regla_Promocion_id_regla_promocion] FOREIGN KEY([id_regla_promocion])
REFERENCES [dbo].[Regla_Promocion] ([id_regla_promocion])
GO
ALTER TABLE [dbo].[volumen_regla_promocion] CHECK CONSTRAINT [FK_Volumen_Regla_Promocion_id_regla_promocion]
GO
