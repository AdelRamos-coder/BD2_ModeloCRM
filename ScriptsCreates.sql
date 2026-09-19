/* ============================================================
   CRM ODERLOGICA - BASE DE DATOS
   Motor: SQL Server
   Archivo 1 de N: creacion de la base de datos y las tablas
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


/* ============================================================
   BLOQUE 1 - CATALOGOS
   Tablas de listas cerradas. No dependen de nadie, por eso van
   primero: una FK no puede apuntar a una tabla que no existe.
   ============================================================ */

/* ---------- PERFIL ----------
   Roles del sistema. El id 1 (Super-administrador) es usado
   por el trigger que impide borrar ese perfil.              */
CREATE TABLE PERFIL (
    id_perfil       INT IDENTITY(1,1),
    tipo_usuario    VARCHAR(30)     NOT NULL,

    CONSTRAINT PK_PERFIL        PRIMARY KEY (id_perfil),
    CONSTRAINT UQ_PERFIL_tipo   UNIQUE (tipo_usuario)
);
GO


/* ---------- FASE ----------
   Etapas del embudo comercial (columnas del Kanban).

   orden : posicion en el embudo. No se puede usar id_fase para
           ordenar porque el IDENTITY asigna numeros por orden de
           insercion, no por posicion en el proceso.
   es_final : marca las fases donde la negociacion termino
           (CERRADO / DESISTIDO). Evita escribir NOT IN (4,5)
           en cada consulta.                                  */
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


/* ---------- MEDIO_CONTACTO ----------
   Por donde se entero el contacto del producto.

   activo : un medio no se puede borrar si tiene prospectos
            historicos apuntando a el. Se desactiva y deja de
            aparecer en el desplegable.                       */
CREATE TABLE MEDIO_CONTACTO (
    id_medio        INT IDENTITY(1,1),
    nombre_medio    VARCHAR(50)     NOT NULL,
    activo          BIT             NOT NULL CONSTRAINT DF_MEDIO_activo DEFAULT 1,

    CONSTRAINT PK_MEDIO         PRIMARY KEY (id_medio),
    CONSTRAINT UQ_MEDIO_nombre  UNIQUE (nombre_medio)
);
GO


/* ---------- PRODUCTO_SERVICIO ---------- */
CREATE TABLE PRODUCTO_SERVICIO (
    id_producto     INT IDENTITY(1,1),
    nombre_producto VARCHAR(100)    NOT NULL,
    activo          BIT             NOT NULL CONSTRAINT DF_PRODUCTO_activo DEFAULT 1,

    CONSTRAINT PK_PRODUCTO          PRIMARY KEY (id_producto),
    CONSTRAINT UQ_PRODUCTO_nombre   UNIQUE (nombre_producto)
);
GO


/* ---------- TIPO_ACTIVIDAD ----------
   automatica : distingue las actividades que registra el sistema
                (Prospecto creado, Cambio de fase, Cambio de
                agente) de las que escribe el asesor. El trigger
                que limita 5 actividades por dia solo debe contar
                las manuales.                                  */
CREATE TABLE TIPO_ACTIVIDAD (
    id_tipo             INT IDENTITY(1,1),
    nombre_actividad    VARCHAR(40)     NOT NULL,
    automatica          BIT             NOT NULL CONSTRAINT DF_TIPOACT_auto DEFAULT 0,

    CONSTRAINT PK_TIPO_ACTIVIDAD        PRIMARY KEY (id_tipo),
    CONSTRAINT UQ_TIPO_ACTIVIDAD_nombre UNIQUE (nombre_actividad)
);
GO


/* ============================================================
   BLOQUE 2 - ENTIDADES PRINCIPALES
   ============================================================ */

/* ---------- TRABAJADOR ----------
   Usuarios del sistema: super-administrador, administrador y
   asesor. El rol lo da id_perfil, no una tabla aparte.

   clave_hash : VARBINARY(32) = salida de HASHBYTES('SHA2_256').
                Nunca se guarda la clave en texto plano.
   activo     : un trabajador jamas se borra, porque miles de
                prospectos lo referencian. Se desactiva.       */
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

/* UNIQUE sobre columnas que admiten NULL.
   Un UNIQUE normal en SQL Server solo tolera UN unico NULL, asi
   que bloquearia al segundo trabajador sin correo. El indice
   filtrado exige unicidad solo entre los que si tienen valor. */
CREATE UNIQUE INDEX UQ_TRABAJADOR_correo
    ON TRABAJADOR (correo)  WHERE correo  IS NOT NULL;
GO
CREATE UNIQUE INDEX UQ_TRABAJADOR_celular
    ON TRABAJADOR (celular) WHERE celular IS NOT NULL;
GO


/* ---------- CONTACTO ----------
   La PERSONA. Existe una sola vez aunque negocie varias veces.
   Separarla de PROSPECTO es lo que elimina la dependencia
   transitiva  id_prospecto -> celular -> nombre  que tenia el
   modelo original del CRM.                                    */
CREATE TABLE CONTACTO (
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

/* Regla del manual: no dos contactos con el mismo correo.
   Filtrado porque el correo es opcional.                      */
CREATE UNIQUE INDEX UQ_CONTACTO_correo
    ON CONTACTO (correo) WHERE correo IS NOT NULL;
GO


/* ---------- PROSPECTO ----------
   La NEGOCIACION. Un contacto puede tener varias, con distinto
   producto, distinto asesor y distinta fase.

   nivel_interes      : las 5 estrellas. TINYINT (1 byte) + CHECK.
                        Es una escala ordinal que se promedia, no
                        una categoria, por eso no es catalogo.
   ultima_actividad   : dato derivado guardado a proposito para no
                        recalcular MAX(fecha) en cada carga del
                        Kanban. Lo mantiene un trigger.
   activo /
   fecha_inactivacion : borrado logico. Un prospecto no se elimina.

   Ninguna FK admite NULL: no existen negociaciones sin dueno,
   sin fase, sin origen ni sin producto.                       */
CREATE TABLE PROSPECTO (
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

    /* Coherencia del borrado logico: si esta activo no puede
       tener fecha de inactivacion, y si esta inactivo debe
       tenerla.                                                */
    CONSTRAINT CK_PROSPECTO_inactivo    CHECK (
        (activo = 1 AND fecha_inactivacion IS NULL) OR
        (activo = 0 AND fecha_inactivacion IS NOT NULL)
    )
);
GO


/* ---------- ACTIVIDAD ----------
   Anotaciones, citas y tareas en una sola tabla. Comparten casi
   todos los campos y el historico las muestra mezcladas en una
   sola linea de tiempo, asi que separarlas obligaria a un UNION
   de tres consultas cada vez.

   fecha_registro   : cuando se escribio la actividad  (pasado).
   fecha_programada : cuando ocurre la cita o tarea    (futuro).
                      Son dos datos distintos, no uno solo.
   id_trabajador    : quien REGISTRO la actividad. Puede no ser el
                      dueno del prospecto (cubrir vacaciones).
   completada       : dispara el registro en LOG_ACTIVIDAD.      */
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


/* ---------- PROPUESTA ----------
   Cotizacion formal con monto. No aparece en el manual: la exige
   el documento de requerimientos.

   Un prospecto puede tener varias propuestas (la inicial, la
   mejorada, la final), por eso es 1:N y no una columna dentro
   de PROSPECTO.

   monto : DECIMAL, NUNCA FLOAT. FLOAT es aproximado y con dinero
           produce valores como 179999999.9999998.
   estado: cuatro valores fijos del proceso comercial. Va como
           CHECK y no como catalogo porque no es una lista que el
           administrador vaya a editar.                        */
CREATE TABLE PROPUESTA (
    id_propuesta        INT IDENTITY(1,1),
    id_prospecto        INT             NOT NULL,
    id_trabajador       INT             NOT NULL,
    monto               DECIMAL(15,2)   NOT NULL,
    fecha_propuesta     DATE            NOT NULL CONSTRAINT DF_PROPUESTA_fecha DEFAULT CAST(SYSDATETIME() AS DATE),
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


/* ============================================================
   BLOQUE 3 - TABLAS TECNICAS

   Estas dos NO llevan claves foraneas, y es intencional.
   Una tabla de auditoria debe sobrevivir al borrado de lo que
   audita: si AUDITORIA tuviera FK hacia PROSPECTO, al borrar el
   prospecto 88 el motor exigiria borrar tambien su rastro, que
   es justamente lo que la auditoria existe para impedir.
   Guardan el identificador suelto, como un numero.
   ============================================================ */

/* ---------- AUDITORIA ---------- */
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


/* ---------- LOG_ACTIVIDAD ---------- */
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


/* ============================================================
   BLOQUE 4 - INDICES

   SQL Server crea el indice de la PRIMARY KEY y de los UNIQUE
   automaticamente, pero NO crea indice para las FOREIGN KEY.
   Ese olvido es la causa mas comun de JOINs lentos: convierte
   una busqueda O(log n) por indice en un recorrido O(n) de toda
   la tabla.

   Aqui coinciden dos necesidades: son las mismas columnas que
   usan los GROUP BY del dashboard.
   ============================================================ */

CREATE INDEX IX_TRABAJADOR_perfil       ON TRABAJADOR (id_perfil);

CREATE INDEX IX_PROSPECTO_contacto      ON PROSPECTO (id_contacto);
CREATE INDEX IX_PROSPECTO_trabajador    ON PROSPECTO (id_trabajador);
CREATE INDEX IX_PROSPECTO_fase          ON PROSPECTO (id_fase);
CREATE INDEX IX_PROSPECTO_medio         ON PROSPECTO (id_medio);
CREATE INDEX IX_PROSPECTO_producto      ON PROSPECTO (id_producto);
CREATE INDEX IX_PROSPECTO_fecha         ON PROSPECTO (fecha_registro);

/* El mas importante del modelo: ACTIVIDAD es la tabla que mas
   crece y el historico siempre filtra por id_prospecto.       */
CREATE INDEX IX_ACTIVIDAD_prospecto     ON ACTIVIDAD (id_prospecto);
CREATE INDEX IX_ACTIVIDAD_tipo          ON ACTIVIDAD (id_tipo);
CREATE INDEX IX_ACTIVIDAD_trabajador    ON ACTIVIDAD (id_trabajador);

/* Indice filtrado: solo indexa lo pendiente, que es lo unico que
   se consulta hacia el futuro. Indice pequeno, consulta rapida. */
CREATE INDEX IX_ACTIVIDAD_pendientes    ON ACTIVIDAD (fecha_programada)
    WHERE completada = 0;

CREATE INDEX IX_PROPUESTA_prospecto     ON PROPUESTA (id_prospecto);
CREATE INDEX IX_PROPUESTA_trabajador    ON PROPUESTA (id_trabajador);

/* Soporta el trigger que impide borrar contactos con propuestas
   en estado 'Activa'.                                          */
CREATE INDEX IX_PROPUESTA_estado        ON PROPUESTA (estado);

CREATE INDEX IX_AUDITORIA_tabla         ON AUDITORIA (tabla_afectada, id_registro);
CREATE INDEX IX_LOG_prospecto           ON LOG_ACTIVIDAD (id_prospecto);
GO


/* ============================================================
   BLOQUE 5 - CARGA DE CATALOGOS

   Los catalogos se cargan con el esquema, no con los datos de
   prueba: los triggers y procedimientos dependen de que ciertos
   identificadores existan (perfil 1 = Super-administrador).
   ============================================================ */

INSERT INTO PERFIL (tipo_usuario) VALUES
    ('Super-administrador'),     -- id 1
    ('Administrador'),           -- id 2
    ('Asesor');                  -- id 3
GO

INSERT INTO FASE (nombre_fase, orden, es_final) VALUES
    ('Contacto inicial',    1, 0),
    ('Cita agendada',       2, 0),
    ('Esperando decision',  3, 0),
    ('Negocio CERRADO',     4, 1),
    ('Negocio DESISTIDO',   5, 1);
GO

INSERT INTO MEDIO_CONTACTO (nombre_medio) VALUES
    ('Campana Redes Sociales'),
    ('Pagina Web'),
    ('Mail Marketing'),
    ('Referido por tercero'),
    ('Contactado por asesor'),
    ('Llamada a oficina'),
    ('Emisora'),
    ('Campana Noticiero'),
    ('Mensaje de Texto'),
    ('Otro');
GO

INSERT INTO PRODUCTO_SERVICIO (nombre_producto) VALUES
    ('Apartamentos Asis'),
    ('Tecnico en Auxiliar de Enfermeria'),
    ('Casa Norte'),
    ('Lotes Campestres'),
    ('Diplomado en Ventas');
GO

INSERT INTO TIPO_ACTIVIDAD (nombre_actividad, automatica) VALUES
    ('Anotacion',        0),
    ('Cita',             0),
    ('Tarea',            0),
    ('Llamada',          0),
    ('Correo',           0),
    ('Prospecto creado', 1),
    ('Cambio de fase',   1),
    ('Cambio de agente', 1);
GO


/* ============================================================
   VERIFICACION
   ============================================================ */

SELECT
    t.name                              AS tabla,
    (SELECT COUNT(*) FROM sys.columns c
      WHERE c.object_id = t.object_id)  AS columnas,
    (SELECT COUNT(*) FROM sys.foreign_keys f
      WHERE f.parent_object_id = t.object_id) AS fks
FROM sys.tables t
ORDER BY t.name;
GO
