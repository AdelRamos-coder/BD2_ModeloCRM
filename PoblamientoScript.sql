USE CRM_Oderlogica;
GO

INSERT INTO PERFIL (tipo_usuario) VALUES
    ('Super-administrador'),
    ('Administrador'),
    ('Asesor'),
    ('Coordinador comercial'),
    ('Auditor');
GO

INSERT INTO FASE (nombre_fase, orden, es_final) VALUES
    ('Contacto inicial',    1, 0),
    ('Cita agendada',       2, 0),
    ('Esperando decision',  3, 0),
    ('Negocio CERRADO',     4, 1),
    ('Negocio DESISTIDO',   5, 1);
GO

INSERT INTO MEDIO_CONTACTO (nombre_medio, activo) VALUES
    ('Campana Redes Sociales', 1),
    ('Pagina Web',             1),
    ('Mail Marketing',         1),
    ('Referido por tercero',   1),
    ('Contactado por asesor',  1),
    ('Llamada a oficina',      1),
    ('Emisora',                1),
    ('Campana Noticiero',      1),
    ('Mensaje de Texto',       1),
    ('Otro',                   0);
GO

INSERT INTO PRODUCTO_SERVICIO (nombre_producto, activo) VALUES
    ('Apartamentos Asis',                 1),
    ('Tecnico en Auxiliar de Enfermeria', 1),
    ('Casa Norte',                        1),
    ('Lotes Campestres',                  1),
    ('Diplomado en Ventas',               0);
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

INSERT INTO TRABAJADOR (nombre_trabajador, login, clave_hash, correo, celular, id_perfil, activo) VALUES
    ('Oderlogica',          'oderlogica', HASHBYTES('SHA2_256','Admin123*'),  'admin@oderlogica.com',    '3008594104', 1, 1),
    ('Andres Bravo',        'abravo',     HASHBYTES('SHA2_256','Andres123*'), 'abravo@oderlogica.com',   '3012345678', 2, 1),
    ('Silvia Gomez',        'sgomez',     HASHBYTES('SHA2_256','Silvia123*'), 'sgomez@oderlogica.com',   '3101112233', 3, 1),
    ('Ramon Gomez',         'rgomez',     HASHBYTES('SHA2_256','Ramon123*'),  'rgomez@oderlogica.com',   '3114445566', 3, 1),
    ('Luis Eduardo Rivera', 'lrivera',    HASHBYTES('SHA2_256','Luis123*'),   'lrivera@oderlogica.com',  '3127778899', 3, 1),
    ('Marcela Mendez',      'mmendez',    HASHBYTES('SHA2_256','Marcela12*'), 'mmendez@oderlogica.com',  '3132223344', 3, 0),
    ('Carolina Ruiz',       'cruiz',      HASHBYTES('SHA2_256','Carol123*'),  'cruiz@oderlogica.com',    '3145556677', 5, 1);
GO

INSERT INTO CONTACTO (nombre_contacto, celular, correo, fecha_registro, activo) VALUES
    ('Pedro Mauricio Gomez', '3092564587', 'pmauriciog@gmail.com',  '2025-03-01 09:15:00', 1),
    ('Alejandra Mocha',      '3202000873', NULL,                    '2025-03-02 10:40:00', 1),
    ('Jessica Alegria',      '3166718614', 'jalegria@gmail.com',    '2025-03-03 08:20:00', 1),
    ('Eric Samboni',         '3117461131', 'esamboni@hotmail.com',  '2025-03-04 14:05:00', 1),
    ('Marlon Bucheli',       '3121259327', 'mbucheli@gmail.com',    '2025-03-05 11:30:00', 1),
    ('Yerly Galue',          '3000108372', 'ygalue@outlook.com',    '2025-03-06 16:50:00', 1),
    ('Anita Ruenes',         '3148744935', 'aruenes@gmail.com',     '2025-03-07 09:00:00', 1),
    ('Osman Figueroa',       '3121803241', NULL,                    '2025-03-08 12:25:00', 0);
GO

INSERT INTO PROSPECTO (id_contacto, id_trabajador, id_fase, id_medio, id_producto, nivel_interes, fecha_registro, ultima_actividad, activo, fecha_inactivacion) VALUES
    (1, 3, 2, 1, 1, 4, '2025-03-01 09:20:00', '2025-03-10 16:42:00', 1, NULL),
    (1, 4, 1, 5, 3, 2, '2025-03-08 10:05:00', '2025-03-08 10:10:00', 1, NULL),
    (2, 3, 1, 2, 1, 5, '2025-03-02 10:45:00', '2025-03-09 11:00:00', 1, NULL),
    (3, 4, 2, 1, 1, 3, '2025-03-03 08:25:00', '2025-03-11 09:30:00', 1, NULL),
    (4, 5, 3, 1, 2, 4, '2025-03-04 14:10:00', '2025-03-12 15:15:00', 1, NULL),
    (5, 5, 4, 3, 1, 5, '2025-03-05 11:35:00', '2025-03-13 17:00:00', 1, NULL),
    (6, 3, 5, 3, 1, 1, '2025-03-06 16:55:00', '2025-03-14 08:45:00', 1, NULL),
    (7, 4, 1, 1, 4, 3, '2025-03-07 09:05:00', NULL,                  1, NULL),
    (8, 5, 1, 6, 2, 2, '2025-03-08 12:30:00', NULL,                  0, '2025-03-15 10:00:00'),
    (2, 5, 3, 4, 4, 4, '2025-03-09 13:40:00', '2025-03-16 12:20:00', 1, NULL);
GO

INSERT INTO ACTIVIDAD (id_prospecto, id_tipo, id_trabajador, descripcion, fecha_registro, fecha_programada, hora_programada, direccion, completada, fecha_completada) VALUES
    (1,  6, 3, N'Prospecto creado',                                   '2025-03-01 09:20:00', NULL,         NULL,       NULL,                    1, '2025-03-01 09:20:00'),
    (1,  2, 3, N'Reunion inicial para presentarle el proyecto',       '2025-03-01 09:25:00', '2025-03-14', '14:00:00', N'Calle 10 #43-25',      0, NULL),
    (1,  7, 3, N'Cambio de fase de [Contacto inicial] a [Cita agendada]', '2025-03-10 16:42:00', NULL,     NULL,       NULL,                    1, '2025-03-10 16:42:00'),
    (2,  1, 4, N'El cliente pidio mas fotos del inmueble',            '2025-03-08 10:10:00', NULL,         NULL,       NULL,                    1, '2025-03-08 10:10:00'),
    (3,  3, 3, N'Enviar cotizacion actualizada por correo',           '2025-03-09 11:00:00', '2025-03-18', '08:00:00', NULL,                    0, NULL),
    (4,  4, 4, N'Llamada de seguimiento, contesto y confirmo interes','2025-03-11 09:30:00', NULL,         NULL,       NULL,                    1, '2025-03-11 09:30:00'),
    (5,  2, 5, N'Visita al proyecto con la familia',                  '2025-03-12 15:15:00', '2025-03-20', '10:30:00', N'Carrera 50 #12-80',    0, NULL),
    (6,  5, 5, N'Envio de contrato firmado',                          '2025-03-13 17:00:00', '2025-03-21', '09:00:00', NULL,                    1, '2025-03-21 09:05:00'),
    (7,  1, 3, N'El prospecto informa que desistio de la compra',     '2025-03-14 08:45:00', NULL,         NULL,       NULL,                    1, '2025-03-14 08:45:00'),
    (10, 3, 5, N'Preparar propuesta comercial para lotes',            '2025-03-16 12:20:00', '2025-03-24', '11:00:00', NULL,                    0, NULL),
    (10, 8, 2, N'Cambio de agente de [Silvia Gomez] a [Luis Eduardo Rivera]', '2025-03-16 12:25:00', NULL, NULL,      NULL,                    1, '2025-03-16 12:25:00'),
    (5,  1, 5, N'Solicita informacion sobre horarios de clase',       '2025-03-17 10:00:00', NULL,         NULL,       NULL,                    1, '2025-03-17 10:00:00');
GO

INSERT INTO PROPUESTA (id_prospecto, id_trabajador, monto, fecha_propuesta, fecha_vencimiento, estado, observacion) VALUES
    (1,  3, 180000000.00, '2025-03-10', '2025-04-10', 'Activa',    N'Cotizacion inicial apartamento 302'),
    (1,  3, 172000000.00, '2025-03-18', '2025-04-18', 'Activa',    N'Cotizacion con descuento por pago de contado'),
    (4,  4,  95000000.00, '2025-03-11', '2025-04-11', 'Rechazada', N'El cliente considero el precio elevado'),
    (5,  5,   3200000.00, '2025-03-12', '2025-04-12', 'Activa',    N'Programa tecnico, plan de pago a 6 cuotas'),
    (6,  5, 210000000.00, '2025-03-13', '2025-04-13', 'Aceptada',  N'Negocio cerrado, pendiente firma de escritura'),
    (10, 5,  48000000.00, '2025-02-01', '2025-03-01', 'Vencida',   N'Lote campestre, oferta no renovada');
GO

INSERT INTO AUDITORIA (tabla_afectada, id_registro, operacion, id_trabajador, fecha_operacion, datos_anteriores) VALUES
    ('PROSPECTO',  1, 'INSERT', 3, '2025-03-01 09:20:00', NULL),
    ('PROSPECTO',  3, 'INSERT', 3, '2025-03-02 10:45:00', NULL),
    ('PROSPECTO',  9, 'INSERT', 5, '2025-03-08 12:30:00', NULL),
    ('PROSPECTO',  9, 'DELETE', 2, '2025-03-15 10:00:00', N'{"id_prospecto":9,"id_contacto":8,"id_fase":1,"nivel_interes":2}'),
    ('CONTACTO',   8, 'UPDATE', 2, '2025-03-15 10:02:00', N'{"id_contacto":8,"activo":1}'),
    ('PROSPECTO', 10, 'INSERT', 5, '2025-03-09 13:40:00', NULL);
GO

INSERT INTO LOG_ACTIVIDAD (id_actividad, id_prospecto, id_trabajador, fecha_completada, mensaje) VALUES
    (1,  1,  3, '2025-03-01 09:20:00', N'Actividad [Prospecto creado] marcada como completada'),
    (4,  2,  4, '2025-03-08 10:10:00', N'Actividad [Anotacion] marcada como completada'),
    (6,  4,  4, '2025-03-11 09:30:00', N'Actividad [Llamada] marcada como completada'),
    (8,  6,  5, '2025-03-21 09:05:00', N'Actividad [Correo] marcada como completada'),
    (9,  7,  3, '2025-03-14 08:45:00', N'Actividad [Anotacion] marcada como completada'),
    (12, 5,  5, '2025-03-17 10:00:00', N'Actividad [Anotacion] marcada como completada');
GO


UNION ALL SELECT 'ACTIVIDAD',         COUNT(*) FROM ACTIVIDAD
UNION ALL SELECT 'PROPUESTA',         COUNT(*) FROM PROPUESTA
UNION ALL SELECT 'AUDITORIA',         COUNT(*) FROM AUDITORIA
UNION ALL SELECT 'LOG_ACTIVIDAD',     COUNT(*) FROM LOG_ACTIVIDAD;
GO
