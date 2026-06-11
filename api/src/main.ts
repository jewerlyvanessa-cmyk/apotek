import './instrument';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { join } from 'path';
import { NestExpressApplication } from '@nestjs/platform-express';
import { existsSync } from 'fs';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const config = app.get(ConfigService);

  app.setGlobalPrefix(config.get('API_PREFIX', 'api/v1'));
  app.enableCors({ origin: config.get('CORS_ORIGIN', '*') });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  app.useGlobalFilters(new HttpExceptionFilter());

  // Serve uploaded files
  const uploadsDir = join(process.cwd(), 'uploads');
  if (existsSync(uploadsDir)) {
    app.useStaticAssets(uploadsDir, { prefix: '/uploads/' });
  }

  const swagger = new DocumentBuilder()
    .setTitle('ApotikFlow API')
    .setDescription('Aplikasi Apotik Multi-Tenant Enterprise')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, swagger);
  SwaggerModule.setup('docs', app, document);

  const port = config.get('PORT', 3000);
  await app.listen(port);
  console.log(`ApotikFlow API running on http://localhost:${port}`);
  console.log(`Swagger: http://localhost:${port}/docs`);
}
bootstrap();
