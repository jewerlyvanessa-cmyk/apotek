import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

/** Hanya cabang aktif — nonaktif hanya lewat modul platform (Super Admin). */
export class BranchQueryDto extends PaginationQueryDto {}
