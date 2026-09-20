/* ============================================================
   CRM ODERLOGICA
   CREATE TABLE - 12 tablas
   Motor: SQL Server
   ============================================================ */

IF DB_ID('CRM_Oderlogica') IS NOT NULL
BEGIN
    ALTER DATABASE CRM_Oderlogica SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CRM_Oderlogica;
END
GO

CREATE DATABASE CRM_Oderlogica;
GO

USE CRM_Oderlogica;
GO


/* ------------------------------------------------------------
   CATALOGOS
   Van primero: una FK no puede apuntar a una tabla inexistente.
   ------------------------------------------------------------ */

CREATE TABLE PERFIL (
    id_perfil       INT IDENTITY(1,1),
    tipo_usuario    VARCHAR(30)     NOT NULL,

    CONSTRAINT PK_PERFIL        PRIMARY KEY (id_perfil),
    CONSTRAINT UQ_PERFIL_tipo   UNIQUE (tipo_usuario)
);
GO


/* orden    : posicion en el embudo. El id_fase no sirve para
              ordenar porque el IDENTITY numera por insercion.
   es_final : la negociacion termino (CERRADO / DESISTIDO).     */
CREATE TABLE FASE (
    id_fase         INT IDENTITY(1,1),
    nombre_fase     VARCHAR(40)     NOT NULL,
    orden           TINYINT         NOT NULL,
    es_final        BIT             NOT NULL CONSTRAINT DF_FASE_final DEFAULT 0,

    CONSTRAINT PK_FASE          PRIMARY KEY (id_fase),
    CONSTRAINT UQ_FASE_nombre   UNIQUE (nombre_fase),
    CONSTRAINT UQ_FASE_orden    UNIQUE (orden)
);
GO


CREATE TABLE MEDIO_CONTACTO (
    id_medio        INT IDENTITY(1,1),
    nombre_medio    VARCHAR(50)     NOT NULL,
    activo          BIT             NOT NULL CONSTRAINT DF_MEDIO_activo DEFAULT 1,

    CONSTRAINT PK_MEDIO         PRIMARY KEY (id_medio),
    CONSTRAINT UQ_MEDIO_nombre  UNIQUE (nombre_medio)
);
GO


CREATE TABLE PRODUCTO_SERVICIO (
    id_producto     INT IDENTITY(1,1),
    nombre_producto VARCHAR(100)    NOT NULL,
    activo          BIT             NOT NULL CONSTRAINT DF_PRODUCTO_activo DEFAULT 1,

    CONSTRAINT PK_PRODUCTO          PRIMARY KEY (id_producto),
    CONSTRAINT UQ_PRODUCTO_nombre   UNIQUE (nombre_producto)
);
GO


/* automatica : separa lo que registra el sistema (Prospecto
                creado, Cambio de fase) de lo que escribe el
                asesor. El trigger que limita 5 actividades por
                dia solo debe contar las manuales.              */
CREATE TABLE TIPO_ACTIVIDAD (
    id_tipo             INT IDENTITY(1,1),
    nombre_actividad    VARCHAR(40)     NOT NULL,
    automatica          BIT             NOT NULL CONSTRAINT DF_TIPOACT_auto DEFAULT 0,

    CONSTRAINT PK_TIPO_ACTIVIDAD        PRIMARY KEY (id_tipo),
    CONSTRAINT UQ_TIPO_ACTIVIDAD_nombre UNIQUE (nombre_actividad)
);
GO


/* ------------------------------------------------------------
   ENTIDADES PRINCIPALES
   ------------------------------------------------------------ */

/* clave_hash : salida de HASHBYTES('SHA2_256'). Nunca texto plano.
   activo     : un trabajador no se borra, se desactiva: miles de
                prospectos lo referencian.                       */
CREATE TABLE TRABAJADOR (
    id_trabajador       INT IDENTITY(1,1),
    nombre_trabajador   VARCHAR(100)    NOT NULL,
    login               VARCHAR(50)     NOT NULL,
    clave_hash          VARBINARY(32)   NOT NULL,
    correo              VARCHAR(150)    NULL,
    celular             VARCHAR(20)     NULL,
    id_perfil           INT             NOT NULL,
    activo              BIT             NOT NULL CONSTRAINT DF_TRABAJADOR_activo DEFAULT 1,
    fecha_creacion      DATETIME2(0)    NOT NULL CONSTRAINT DF_TRABAJADOR_fecha  DEFAULT SYSDATETIME(),

    CONSTRAINT PK_TRABAJADOR        PRIMARY KEY (id_trabajador),
    CONSTRAINT UQ_TRABAJADOR_login  UNIQUE (login),
    CONSTRAINT FK_TRABAJADOR_perfil FOREIGN KEY (id_perfil)
        REFERENCES PERFIL (id_perfil)
);
GO


/* La PERSONA. Existe una sola vez aunque negocie varias veces.
   Separarla de PROSPECTO elimina la dependencia transitiva
   id_prospecto -> celular -> nombre del modelo original.        */
CREATE TABLE PROSPECTO (
    id_contacto     INT IDENTITY(1,1),
    nombre_contacto VARCHAR(150)    NOT NULL,
    celular         VARCHAR(20)     NOT NULL,
    correo          VARCHAR(150)    NULL,
    fecha_registro  DATETIME2(0)    NOT NULL CONSTRAINT DF_CONTACTO_fecha  DEFAULT SYSDATETIME(),
    activo          BIT             NOT NULL CONSTRAINT DF_CONTACTO_activo DEFAULT 1,

    CONSTRAINT PK_CONTACTO          PRIMARY KEY (id_contacto),
    CONSTRAINT UQ_CONTACTO_celular  UNIQUE (celular)
);
GO


/* La NEGOCIACION. Un contacto puede tener varias, con distinto
   producto, asesor y fase.

   nivel_interes      : las 5 estrellas. Escala ordinal que se
                        promedia, por eso es numero y no catalogo.
   ultima_actividad   : derivado guardado a proposito para no
                        recalcular MAX(fecha) en cada carga del
                        Kanban. Lo mantiene un trigger.
   activo /
   fecha_inactivacion : borrado logico.                          */
CREATE TABLE NEGOCIO (
    id_prospecto        INT IDENTITY(1,1),
    id_contacto         INT             NOT NULL,
    id_trabajador       INT             NOT NULL,
    id_fase             INT             NOT NULL,
    id_medio            INT             NOT NULL,
    id_producto         INT             NOT NULL,
    nivel_interes       TINYINT         NOT NULL CONSTRAINT DF_PROSPECTO_nivel  DEFAULT 1,
    fecha_registro      DATETIME2(0)    NOT NULL CONSTRAINT DF_PROSPECTO_fecha  DEFAULT SYSDATETIME(),
    ultima_actividad    DATETIME2(0)    NULL,
    activo              BIT             NOT NULL CONSTRAINT DF_PROSPECTO_activo DEFAULT 1,
    fecha_inactivacion  DATETIME2(0)    NULL,

    CONSTRAINT PK_PROSPECTO             PRIMARY KEY (id_prospecto),

    CONSTRAINT FK_PROSPECTO_contacto    FOREIGN KEY (id_contacto)
        REFERENCES CONTACTO (id_contacto),
    CONSTRAINT FK_PROSPECTO_trabajador  FOREIGN KEY (id_trabajador)
        REFERENCES TRABAJADOR (id_trabajador),
    CONSTRAINT FK_PROSPECTO_fase        FOREIGN KEY (id_fase)
        REFERENCES FASE (id_fase),
    CONSTRAINT FK_PROSPECTO_medio       FOREIGN KEY (id_medio)
        REFERENCES MEDIO_CONTACTO (id_medio),
    CONSTRAINT FK_PROSPECTO_producto    FOREIGN KEY (id_producto)
        REFERENCES PRODUCTO_SERVICIO (id_producto),

    CONSTRAINT CK_PROSPECTO_nivel       CHECK (nivel_interes BETWEEN 1 AND 5),

    CONSTRAINT CK_PROSPECTO_inactivo    CHECK (
        (activo = 1 AND fecha_inactivacion IS NULL) OR
        (activo = 0 AND fecha_inactivacion IS NOT NULL)
    )
);
GO


/* Anotaciones, citas y tareas en una sola tabla: comparten casi
   todos los campos y el historico las muestra mezcladas.

   fecha_registro   : cuando se escribio      (pasado)
   fecha_programada : cuando ocurre la cita   (futuro)
   id_trabajador    : quien REGISTRO la actividad, que puede no
                      ser el dueno del prospecto.                */
CREATE TABLE ACTIVIDAD (
    id_actividad        INT IDENTITY(1,1),
    id_prospecto        INT             NOT NULL,
    id_tipo             INT             NOT NULL,
    id_trabajador       INT             NOT NULL,
    descripcion         NVARCHAR(MAX)   NOT NULL,
    fecha_registro      DATETIME2(0)    NOT NULL CONSTRAINT DF_ACTIVIDAD_fecha DEFAULT SYSDATETIME(),
    fecha_programada    DATE            NULL,
    hora_programada     TIME(0)         NULL,
    direccion           VARCHAR(200)    NULL,
    completada          BIT             NOT NULL CONSTRAINT DF_ACTIVIDAD_comp  DEFAULT 0,
    fecha_completada    DATETIME2(0)    NULL,

    CONSTRAINT PK_ACTIVIDAD             PRIMARY KEY (id_actividad),

    CONSTRAINT FK_ACTIVIDAD_prospecto   FOREIGN KEY (id_prospecto)
        REFERENCES PROSPECTO (id_prospecto),
    CONSTRAINT FK_ACTIVIDAD_tipo        FOREIGN KEY (id_tipo)
        REFERENCES TIPO_ACTIVIDAD (id_tipo),
    CONSTRAINT FK_ACTIVIDAD_trabajador  FOREIGN KEY (id_trabajador)
        REFERENCES TRABAJADOR (id_trabajador),

    CONSTRAINT CK_ACTIVIDAD_completada  CHECK (
        (completada = 0 AND fecha_completada IS NULL) OR
        (completada = 1 AND fecha_completada IS NOT NULL)
    )
);
GO


/* Cotizacion formal. Un prospecto puede tener varias (inicial,
   mejorada, final), por eso 1:N y no una columna en PROSPECTO.

   monto  : DECIMAL, nunca FLOAT. FLOAT es aproximado y con dinero
            produce valores como 179999999.9999998.
   estado : cuatro valores fijos del proceso. CHECK y no catalogo
            porque no es una lista que el administrador edite.    */
CREATE TABLE PROPUESTA (
    id_propuesta        INT IDENTITY(1,1),
    id_prospecto        INT             NOT NULL,
    id_trabajador       INT             NOT NULL,
    monto               DECIMAL(15,2)   NOT NULL,
    fecha_propuesta     DATE            NOT NULL CONSTRAINT DF_PROPUESTA_fecha  DEFAULT CAST(SYSDATETIME() AS DATE),
    fecha_vencimiento   DATE            NULL,
    estado              VARCHAR(20)     NOT NULL CONSTRAINT DF_PROPUESTA_estado DEFAULT 'Activa',
    observacion         NVARCHAR(500)   NULL,

    CONSTRAINT PK_PROPUESTA             PRIMARY KEY (id_propuesta),

    CONSTRAINT FK_PROPUESTA_prospecto   FOREIGN KEY (id_prospecto)
        REFERENCES PROSPECTO (id_prospecto),
    CONSTRAINT FK_PROPUESTA_trabajador  FOREIGN KEY (id_trabajador)
        REFERENCES TRABAJADOR (id_trabajador),

    CONSTRAINT CK_PROPUESTA_monto       CHECK (monto >= 0),
    CONSTRAINT CK_PROPUESTA_estado      CHECK (estado IN
        ('Activa','Aceptada','Rechazada','Vencida')),
    CONSTRAINT CK_PROPUESTA_vence       CHECK (
        fecha_vencimiento IS NULL OR fecha_vencimiento >= fecha_propuesta)
);
GO


/* ------------------------------------------------------------
   TABLAS TECNICAS

   Sin claves foraneas, a proposito. Si AUDITORIA tuviera FK
   hacia PROSPECTO, al borrar el prospecto 88 el motor exigiria
   borrar tambien su rastro, que es justo lo que la auditoria
   existe para impedir. Guardan el identificador suelto.
   ------------------------------------------------------------ */

CREATE TABLE AUDITORIA (
    id_auditoria        BIGINT IDENTITY(1,1),
    tabla_afectada      VARCHAR(50)     NOT NULL,
    id_registro         INT             NOT NULL,
    operacion           VARCHAR(10)     NOT NULL,
    id_trabajador       INT             NULL,
    usuario_sql         SYSNAME         NOT NULL CONSTRAINT DF_AUDITORIA_user  DEFAULT SUSER_SNAME(),
    fecha_operacion     DATETIME2(0)    NOT NULL CONSTRAINT DF_AUDITORIA_fecha DEFAULT SYSDATETIME(),
    datos_anteriores    NVARCHAR(MAX)   NULL,

    CONSTRAINT PK_AUDITORIA         PRIMARY KEY (id_auditoria),
    CONSTRAINT CK_AUDITORIA_oper    CHECK (operacion IN ('INSERT','UPDATE','DELETE'))
);
GO


CREATE TABLE LOG_ACTIVIDAD (
    id_log              BIGINT IDENTITY(1,1),
    id_actividad        INT             NOT NULL,
    id_prospecto        INT             NOT NULL,
    id_trabajador       INT             NULL,
    fecha_completada    DATETIME2(0)    NOT NULL CONSTRAINT DF_LOG_fecha DEFAULT SYSDATETIME(),
    mensaje             NVARCHAR(500)   NULL,

    CONSTRAINT PK_LOG_ACTIVIDAD PRIMARY KEY (id_log)
);
GO
