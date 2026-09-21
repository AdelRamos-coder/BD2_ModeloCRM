USE CRM_Oderlogica;
GO

CREATE TRIGGER TRG_PROSPECTO_EvitarBorradoConPropuestaActiva
ON PROSPECTO
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM DELETED d
        INNER JOIN NEGOCIO n  ON n.id_prospecto = d.id_prospecto
        INNER JOIN PROPUESTA p ON p.id_negocio   = n.id_negocio
        WHERE p.estado = 'Activa'
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('No se puede eliminar el prospecto: tiene propuestas en estado Activa.', 16, 1);
        RETURN;
    END
END
GO




CREATE PROCEDURE SP_CambiarAsesorProspecto
    @id_negocio             INT,
    @id_nuevo_asesor        INT,
    @id_trabajador_ejecuta  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @tipo_perfil VARCHAR(30);

    SELECT @tipo_perfil = pf.tipo_usuario
    FROM TRABAJADOR t
    INNER JOIN PERFIL pf ON pf.id_perfil = t.id_perfil
    WHERE t.id_trabajador = @id_trabajador_ejecuta;

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

    IF NOT EXISTS (SELECT 1 FROM NEGOCIO WHERE id_negocio = @id_negocio)
    BEGIN
        RAISERROR('El negocio indicado no existe.', 16, 1);
        RETURN;
    END

    DECLARE @nombre_anterior VARCHAR(100);
    DECLARE @nombre_nuevo    VARCHAR(100);

    SELECT @nombre_anterior = t.nombre_trabajador
    FROM NEGOCIO n
    INNER JOIN TRABAJADOR t ON t.id_trabajador = n.id_trabajador
    WHERE n.id_negocio = @id_negocio;

    SELECT @nombre_nuevo = nombre_trabajador
    FROM TRABAJADOR
    WHERE id_trabajador = @id_nuevo_asesor;

    IF @nombre_nuevo IS NULL
    BEGIN
        RAISERROR('El nuevo asesor no existe.', 16, 1);
        RETURN;
    END

    UPDATE NEGOCIO
    SET id_trabajador = @id_nuevo_asesor
    WHERE id_negocio = @id_negocio;

    DECLARE @id_tipo_cambio INT;
    SELECT @id_tipo_cambio = id_tipo
    FROM TIPO_ACTIVIDAD
    WHERE nombre_actividad = 'Cambio de agente';

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



CREATE PROCEDURE SP_ConsultarProspectos
    @nombre         VARCHAR(150) = NULL,
    @celular        VARCHAR(20)  = NULL,
    @id_asesor      INT          = NULL,
    @fecha_registro DATE         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        p.id_prospecto,
        p.nombre_prospecto,
        p.celular,
        p.correo,
        p.fecha_registro,
        p.activo
    FROM PROSPECTO p
    LEFT JOIN NEGOCIO n ON n.id_prospecto = p.id_prospecto
    WHERE (@nombre  IS NULL OR p.nombre_prospecto LIKE '%' + @nombre + '%')
      AND (@celular IS NULL OR p.celular = @celular)
      AND (@id_asesor IS NULL OR n.id_trabajador = @id_asesor)
      AND (@fecha_registro IS NULL OR CAST(p.fecha_registro AS DATE) = @fecha_registro);
END
GO

CREATE FUNCTION FN_PromedioNivelInteres()
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @promedio DECIMAL(5,2);

    SELECT @promedio = AVG(CAST(nivel_interes AS DECIMAL(5,2)))
    FROM NEGOCIO;

    RETURN @promedio;
END
GO




CREATE FUNCTION FN_DiasDesdeRegistro(@fecha_registro DATETIME2(0))
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(DAY, @fecha_registro, SYSDATETIME());
END
GO
