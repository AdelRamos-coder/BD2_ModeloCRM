USE CRM_Oderlogica;
GO

--Trigger 1



--Trigger 2

CREATE TRIGGER TRG_PROSPECTO_EvitarBorradoConPropuestaActiva
ON PROSPECTO
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM deleted del
        INNER JOIN NEGOCIO neg   ON neg.id_prospecto = del.id_prospecto
        INNER JOIN PROPUESTA prp ON prp.id_negocio   = neg.id_negocio
        WHERE prp.estado = 'Activa'
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('No se puede eliminar el prospecto: tiene propuestas en estado Activa.', 16, 1);
        RETURN;
    END
END
GO


--Trigger 3

CREATE TRIGGER trg_ActualizarUltimaActividad
ON ACTIVIDAD
AFTER INSERT
AS
BEGIN

    UPDATE NEGOCIO
    SET ultima_actividad = SYSDATETIME()
    WHERE id_negocio IN (SELECT ins.id_negocio FROM inserted ins);

END;
GO


--Trigger 4

CREATE TRIGGER trg_ValidarMontoPropuesta
ON PROPUESTA
AFTER INSERT, UPDATE
AS
BEGIN

    IF EXISTS (SELECT 1 FROM inserted ins WHERE ins.monto < 0)
    BEGIN
        RAISERROR('El monto no puede ser negativo', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

END;
GO


--Trigger 5

CREATE TRIGGER trg_LimitarActividades
ON ACTIVIDAD
AFTER INSERT
AS
BEGIN
    DECLARE @negocio INT;
    DECLARE @fecha DATE;
    DECLARE @cantidad INT;

    SELECT @negocio = ins.id_negocio, @fecha = CAST(ins.fecha_registro AS DATE)
    FROM inserted ins;

    SELECT @cantidad = COUNT(*)
    FROM ACTIVIDAD act
    WHERE act.id_negocio = @negocio
      AND CAST(act.fecha_registro AS DATE) = @fecha;

    IF @cantidad > 5
    BEGIN
        ROLLBACK;
        THROW 50001, 'No se permiten más de 5 actividades al día.', 1;
    END
END;
GO


--Trigger 6



--Trigger 7

CREATE TRIGGER trg_PrevenirCorreoDuplicado
ON PROSPECTO
AFTER INSERT
AS
BEGIN

    IF EXISTS (SELECT 1
               FROM PROSPECTO pro
               WHERE pro.correo IS NOT NULL
               GROUP BY pro.correo
               HAVING COUNT(*) > 1)
    BEGIN
        RAISERROR('El correo ya esta registrado', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

END;
GO


--Trigger 8

CREATE TRIGGER trg_LogActividadCompletada
ON ACTIVIDAD
AFTER UPDATE
AS
BEGIN
    INSERT INTO LOG_ACTIVIDAD
    (id_actividad, id_negocio, id_trabajador, mensaje)
    SELECT
        ins.id_actividad,
        ins.id_negocio,
        ins.id_trabajador,
        'Actividad completada'
    FROM inserted ins
    INNER JOIN deleted del
        ON ins.id_actividad = del.id_actividad
    WHERE del.completada = 0
      AND ins.completada = 1;
END;
GO


--Trigger 9

CREATE TRIGGER trg_BorradoLogicoProspecto
ON PROSPECTO
INSTEAD OF DELETE
AS
BEGIN
    UPDATE pro
    SET
        activo = 0,
        fecha_inactivacion = SYSDATETIME()
    FROM PROSPECTO pro
    INNER JOIN deleted del
        ON pro.id_prospecto = del.id_prospecto;
END;
GO


--Trigger 10



--Procedimiento 1

CREATE PROCEDURE usp_RegistrarProspecto
    @nombre        VARCHAR(150),
    @celular       VARCHAR(20),
    @correo        VARCHAR(150),
    @id_medio      INT,
    @id_producto   INT,
    @nivel_interes TINYINT,
    @id_trabajador INT
AS
BEGIN

    SET XACT_ABORT ON;

    DECLARE @id_prospecto INT;
    DECLARE @id_fase      INT;

    IF EXISTS (SELECT 1 FROM PROSPECTO pro WHERE pro.celular = @celular)
    BEGIN
        RAISERROR('El celular ya esta registrado en otro prospecto.', 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;

    INSERT INTO PROSPECTO (nombre_prospecto, celular, correo)
    VALUES (@nombre, @celular, @correo);

    SET @id_prospecto = SCOPE_IDENTITY();

    SELECT @id_fase = fas.id_fase
    FROM FASE fas
    WHERE fas.orden = 1;

    INSERT INTO NEGOCIO (id_prospecto, id_trabajador, id_fase, id_medio, id_producto, nivel_interes)
    VALUES (@id_prospecto, @id_trabajador, @id_fase, @id_medio, @id_producto, @nivel_interes);

    COMMIT TRANSACTION;

END;
GO


--Procedimiento 2



--Procedimiento 3

CREATE PROCEDURE sp_RegistrarActividad
    @id_negocio INT,
    @id_tipo INT,
    @id_trabajador INT,
    @descripcion NVARCHAR(MAX),
    @fecha_programada DATE = NULL,
    @hora_programada TIME(0) = NULL,
    @direccion VARCHAR(200) = NULL
AS
BEGIN
    INSERT INTO ACTIVIDAD
    (
        id_negocio,
        id_tipo,
        id_trabajador,
        descripcion,
        fecha_programada,
        hora_programada,
        direccion
    )
    VALUES
    (
        @id_negocio,
        @id_tipo,
        @id_trabajador,
        @descripcion,
        @fecha_programada,
        @hora_programada,
        @direccion
    );
END;
GO


--Procedimiento 4

CREATE PROCEDURE SP_CambiarAsesorProspecto
    @id_negocio             INT,
    @id_nuevo_asesor        INT,
    @id_trabajador_ejecuta  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @tipo_perfil VARCHAR(30);

    SELECT @tipo_perfil = per.tipo_usuario
    FROM TRABAJADOR tra
    INNER JOIN PERFIL per ON per.id_perfil = tra.id_perfil
    WHERE tra.id_trabajador = @id_trabajador_ejecuta;

    IF @tipo_perfil IS NULL
    BEGIN
        RAISERROR('El trabajador que ejecuta la accion no existe.', 16, 1);
        RETURN;
    END

    IF @tipo_perfil NOT IN ('Super-administrador', 'Administrador')
    BEGIN
        RAISERROR('Solo un usuario administrativo puede cambiar el asesor.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM NEGOCIO neg WHERE neg.id_negocio = @id_negocio)
    BEGIN
        RAISERROR('El negocio indicado no existe.', 16, 1);
        RETURN;
    END

    DECLARE @nombre_anterior VARCHAR(100);
    DECLARE @nombre_nuevo    VARCHAR(100);

    SELECT @nombre_anterior = tra.nombre_trabajador
    FROM NEGOCIO neg
    INNER JOIN TRABAJADOR tra ON tra.id_trabajador = neg.id_trabajador
    WHERE neg.id_negocio = @id_negocio;

    SELECT @nombre_nuevo = tra.nombre_trabajador
    FROM TRABAJADOR tra
    WHERE tra.id_trabajador = @id_nuevo_asesor;

    IF @nombre_nuevo IS NULL
    BEGIN
        RAISERROR('El nuevo asesor no existe.', 16, 1);
        RETURN;
    END

    UPDATE NEGOCIO
    SET id_trabajador = @id_nuevo_asesor
    WHERE id_negocio = @id_negocio;

    DECLARE @id_tipo_cambio INT;
    SELECT @id_tipo_cambio = tip.id_tipo
    FROM TIPO_ACTIVIDAD tip
    WHERE tip.nombre_actividad = 'Cambio de agente';

    INSERT INTO ACTIVIDAD (id_negocio, id_tipo, id_trabajador, descripcion, completada, fecha_completada)
    VALUES (
        @id_negocio,
        @id_tipo_cambio,
        @id_trabajador_ejecuta,
        CONCAT(N'Cambio de agente de [', @nombre_anterior, N'] a [', @nombre_nuevo, N']'),
        1,
        SYSDATETIME()
    );
END
GO


--Procedimiento 5

CREATE PROCEDURE SP_ConsultarProspectos
    @nombre         VARCHAR(150) = NULL,
    @celular        VARCHAR(20)  = NULL,
    @id_asesor      INT          = NULL,
    @fecha_registro DATE         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        pro.id_prospecto,
        pro.nombre_prospecto,
        pro.celular,
        pro.correo,
        pro.fecha_registro,
        pro.activo
    FROM PROSPECTO pro
    LEFT JOIN NEGOCIO neg ON neg.id_prospecto = pro.id_prospecto
    WHERE (@nombre  IS NULL OR pro.nombre_prospecto LIKE '%' + @nombre + '%')
      AND (@celular IS NULL OR pro.celular = @celular)
      AND (@id_asesor IS NULL OR neg.id_trabajador = @id_asesor)
      AND (@fecha_registro IS NULL OR CAST(pro.fecha_registro AS DATE) = @fecha_registro);
END
GO


--Funcion 1

CREATE FUNCTION fn_ContarNegociosAsesor (@id_trabajador INT)
RETURNS INT
AS
BEGIN

    DECLARE @cantidad INT;

    SELECT @cantidad = COUNT(*)
    FROM NEGOCIO neg
    WHERE neg.id_trabajador = @id_trabajador
      AND neg.activo = 1;

    RETURN @cantidad;

END;
GO


--Funcion 2



--Funcion 3

CREATE FUNCTION fn_TotalActividadesProspecto
(
    @id_prospecto INT
)
RETURNS INT
AS
BEGIN
    DECLARE @total INT;

    SELECT @total = COUNT(*)
    FROM ACTIVIDAD act
    INNER JOIN NEGOCIO neg
        ON act.id_negocio = neg.id_negocio
    WHERE neg.id_prospecto = @id_prospecto;

    RETURN @total;
END;
GO


--Funcion 4

CREATE FUNCTION FN_PromedioNivelInteres()
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @promedio DECIMAL(5,2);

    SELECT @promedio = AVG(CAST(neg.nivel_interes AS DECIMAL(5,2)))
    FROM NEGOCIO neg;

    RETURN @promedio;
END
GO


--Funcion 5

CREATE FUNCTION FN_DiasDesdeRegistro(@fecha_registro DATETIME2(0))
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(DAY, @fecha_registro, SYSDATETIME());
END
GO

