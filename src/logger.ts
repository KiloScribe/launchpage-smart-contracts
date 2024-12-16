import winston from "winston";

const { format } = winston;
const { combine, timestamp, printf } = format;

const myFormat = printf(({ level, message, timestamp }: winston.Logform.TransformableInfo) => {
  return `${timestamp} ${level}: ${message}`;
});

export const Logger = winston.createLogger({
  format: combine(timestamp(), myFormat),
  transports: [
    new winston.transports.Console({ 
      silent: process.env.NODE_ENV === "test" 
    }),
    new winston.transports.File({ 
      filename: "log/logs.log" 
    }),
  ],
});
