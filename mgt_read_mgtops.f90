      subroutine mgt_read_mgtops
      
      use input_file_module
      use maximum_data_module
      use mgt_operations_module
      
      character (len=80) :: titldum
      character (len=80) :: header
      character (len=13) :: file
      integer :: eof, nops, m_auto

      eof = 0
      imax = 0
        
      !!   read mgtops.dat file
      !! calculate number of records in management 
      inquire (file=in_lum%management_sch, exist=i_exist)
      if (i_exist == 0 .or. in_lum%management_sch == 'null') then
        allocate (sched(0:0))
      else
      do
       open (107,file=in_lum%management_sch)
       read (107,*,iostat=eof) titldum
       if (eof < 0) exit
       read (107,*,iostat=eof) header
       if (eof < 0) exit
       do while (eof == 0)
         read (107,*,iostat=eof) titldum, nops, nauto
         if (eof < 0) exit
         do iauto = 1, nauto
           read (107,*,iostat=eof) titldum
           if (eof < 0) exit
         end do
         do iops = 1, nops
           read (107,*,iostat=eof) titldum
           if (eof < 0) exit
         end do
         imax = imax + 1
       end do 
       
       allocate (sched(0:imax))
       
       rewind (107)
       read (107,*) titldum
       read (107,*) header
       
       do isched = 1, imax
         read (107,*,iostat=eof)  sched(isched)%name, sched(isched)%num_ops, sched(isched)%num_autos
         if (eof < 0) exit
         !! allocate and read the auto operations
         m_autos = sched(isched)%num_autos
         if (m_autos > 0) then
           allocate(sched(isched)%auto_name(m_autos))
           allocate(sched(isched)%num_db(m_autos))
           do iauto = 1, m_autos
             read (107,*,iostat=eof)  sched(isched)%auto_name(iauto)
             if (eof < 0) exit
           end do
         end if
         !! allocate and read the scheduled operations
         allocate (sched(isched)%mgt_ops(sched(isched)%num_ops))
         call read_mgtops(isched)
       end do
       exit
      enddo
      endif
      db_mx%mgt_ops = imax
       
      close(107)
      
      return     
      end subroutine mgt_read_mgtops