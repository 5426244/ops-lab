CREATE DATABASE IF NOT EXISTS opslab;
USE opslab;

DROP TABLE IF EXISTS emp;
DROP TABLE IF EXISTS dept;

CREATE TABLE dept (
  dept_id   INT PRIMARY KEY,
  dept_name VARCHAR(30) NOT NULL,
  location  VARCHAR(30)
);

CREATE TABLE emp (
  emp_id    INT PRIMARY KEY AUTO_INCREMENT,
  emp_name  VARCHAR(30) NOT NULL,
  dept_id   INT,
  salary    INT,
  hire_date DATE,
  status    VARCHAR(10) DEFAULT 'active'
);

INSERT INTO dept VALUES
(10, '运维部',   '北京'),
(20, '安全部',   '上海'),
(30, '研发部',   '深圳'),
(40, '行政部',   '北京'),
(50, '测试部',   '杭州');

INSERT INTO emp (emp_name, dept_id, salary, hire_date, status) VALUES
('张野',   10, 12000, '2026-07-01', 'active'),
('李明',   10, 15000, '2024-03-15', 'active'),
('王芳',   10,  9800, '2025-09-01', 'active'),
('赵强',   10, 21000, '2022-05-20', 'active'),
('孙悦',   10, 13500, '2023-11-11', 'active'),
('周涛',   20, 16000, '2023-02-08', 'active'),
('吴敏',   20,  8800, '2026-01-10', 'active'),
('郑凯',   20, 19200, '2021-08-30', 'active'),
('冯雪',   20, 11000, '2025-04-22', 'inactive'),
('陈杰',   30, 25000, '2020-06-15', 'active'),
('褚磊',   30, 18000, '2022-12-01', 'active'),
('卫兰',   30, 14500, '2024-09-09', 'active'),
('蒋涛',   30,  9500, '2026-03-18', 'active'),
('沈悦',   30, 22000, '2021-10-05', 'inactive'),
('韩梅',   40,  7500, '2025-02-14', 'active'),
('杨帆',   40,  8200, '2024-07-07', 'active'),
('朱琳',   50,  9000, '2025-12-25', 'active'),
('秦海',   50, 10500, '2023-06-30', 'active'),
('尤静',   50, 12500, '2022-04-12', 'active'),
('许峰',   10, 17000, '2020-01-20', 'active');
