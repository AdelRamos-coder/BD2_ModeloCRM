--Trigger 4

CREATE TRIGGER trg_ValidarMontoPropuesta
ON PROPUESTA
AFTER INSERT, UPDATE
AS
BEGIN

    IF EXISTS (SELECT 1 FROM inserted WHERE monto < 0)
    BEGIN
        RAISERROR('El monto no puede ser negativo', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

END;
GO


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
