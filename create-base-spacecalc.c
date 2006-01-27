/******************* create-base-spacecalc.c *******************/

/* This is a helper program used when calculating space and
   partition cylinders. Purpose is kind of specific to
   the crypto-boot-mgr shell scripts. Needs to be better
   documented. */

/* Copyright (C) 2005,2006 by Marc Chatel, chatelm@yahoo.com

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
  
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA */

#include <stdio.h>
#include <stdlib.h>
#include <strings.h>

/* Arguments expected are:
   1   : total size of device in MB
   2   : total size of device in cylinders
   3   : total preferred size allocation in percentage (x if undefined)
   4   : number of partitions

   for each partition

   n   : preferred size percentage (x if undefined)
   n+1 : minimum size in megabytes (x if undefined) */

#define MAX_NUM_PARTITIONS   4

int main( int argc, char **argv )
{
   int total_dev_size_mb             = 0;
   int total_dev_size_cyls           = 0;

   int def_pref_percent_size_alloc   = 0;
   int total_pref_percent_size_alloc = 0;
   int dev_percent_size_mb           = 0;

   int num_partitions                = 0;

   int part_min_size[MAX_NUM_PARTITIONS + 1];
   int def_part_min_size[MAX_NUM_PARTITIONS + 1];
   int sum_min_sizes = 0;

   int part_pref_size_percent[MAX_NUM_PARTITIONS + 1];
   int def_part_pref_size_percent[MAX_NUM_PARTITIONS + 1];
   int sum_pref_sizes = 0;
   int num_partitions_percent_unspecified = 0;
   int per_unspec_partition_percent_alloc = 0;

   int part_actual_size_mb[MAX_NUM_PARTITIONS + 1];
   int part_actual_size_cyls[MAX_NUM_PARTITIONS + 1];

   int idx = 0;

   for (idx = 0; idx <= MAX_NUM_PARTITIONS; idx++)
   {
      part_min_size[idx]              =  0;
      def_part_min_size[idx]          =  1;

      part_pref_size_percent[idx]     = -1;
      def_part_pref_size_percent[idx] =  1;

      part_actual_size_mb[idx]        = -1;
      part_actual_size_cyls[idx]      = -1;
   }

   if (argc < 5)
   {
      printf("ERROR %s: called with less than 4 arguments\n", argv[0]);
      return 1;
   }

   total_dev_size_mb = atoi( argv[1] );
   if (total_dev_size_mb <= 0)
   {
      printf( "ERROR Parameter 1 (Total device size in MB) %s\n",
                 "should be > 0" );
      return 1;
   }

   total_dev_size_cyls = atoi( argv[2] );
   if (total_dev_size_cyls <= 0)
   {
      printf( "ERROR Parameter 2 (Total device size in cylinders) %s\n",
                 "should be > 0" );
      return 1;
   }

   if (strcasecmp( argv[3], "x" ) == 0)
   {
      total_pref_percent_size_alloc = 100;
      def_pref_percent_size_alloc   = 1;
   }
   else
   {
      total_pref_percent_size_alloc = atoi( argv[3] );

      if ((total_pref_percent_size_alloc <= 0) ||
          (total_pref_percent_size_alloc > 100))
      {
         printf("ERROR Parameter 3 (%s) should be in the range 0-100\n",
                "Preferred total % allocation of device" );
         return 1;
      }
   }

   num_partitions = atoi( argv[4] );

   if ((num_partitions < 1) || (num_partitions > MAX_NUM_PARTITIONS))
   {
      printf( "ERROR Parameter 4 (%s) should be in the range 1-%d\n",
                 "Number of partitions", MAX_NUM_PARTITIONS );
      return 1;
   }

   if (argc != (5 + (2 * num_partitions)))
   {
      printf( "ERROR For each partitions, %s\n",
              "exactly 2 parameters must be specified." );
      return 1;
   }

   for (idx = 1; idx <= num_partitions; idx++ )
   {
      if (strcasecmp( argv[idx + idx + 3], "x" ) == 0)
      { } /* preferred size percentage is not specified,
             leave at default -1 */
      else
      {
         part_pref_size_percent[idx] = atoi(argv[idx + idx + 3]);
         def_part_pref_size_percent[idx] = 0;

         if ((part_pref_size_percent[idx] <= 0) ||
             (part_pref_size_percent[idx] > 100))
         {
            printf( "ERROR Preferred size percentage for partition " );
            printf( "%d should be in range 1-100\n", idx );
            return 1;
         }
      }

      if (strcasecmp( argv[idx + idx + 4], "x" ) == 0)
      { } /* minimum size is not specified, leave at default 0 */
      else
      {
         part_min_size[idx] = atoi(argv[idx + idx + 4]);
         def_part_min_size[idx] = 0;

         if (part_min_size[idx] <= 0)
         {
            printf( "ERROR Minimum size for partition %d %s\n",
                    idx, "should be >= 0" );
            return 1;
         }
      }
   }

   for (idx = 1; idx <= num_partitions; idx++)
       sum_min_sizes += part_min_size[idx];

   /* printf( "DEBUG Sum of minimum sizes is %d\n", sum_min_sizes ); */

   dev_percent_size_mb = total_dev_size_mb *
                         total_pref_percent_size_alloc / 100;

   /* printf( "DEBUG Device space (MB) that can be allocated: %d\n",
           dev_percent_size_mb ); */

   /* Check that the sum of the partition min sizes is 
      <= dev_percent_size_mb */

   if (sum_min_sizes > dev_percent_size_mb)
   {
      printf( "ERROR Sum of partition minimum sizes > %s\n",
              "Preferred total size percentage allocation for device" );
      return 1;
   }

   for (idx = 1; idx <= num_partitions; idx++)
      if (part_pref_size_percent[idx] >= 0)
         sum_pref_sizes += part_pref_size_percent[idx];
      else
         num_partitions_percent_unspecified++;

   /* printf( "DEBUG sum of all preferred size percents: %d\n",
              sum_pref_sizes );
      printf( "DEBUG number of partitions without size percents: %d\n",
              num_partitions_percent_unspecified );
   */
 
   if (sum_pref_sizes > total_pref_percent_size_alloc)
   {
      printf( "ERROR Sum of partition preferred size percentages " );
      printf( "> device total preferred percentage allocation\n" );
      return 1;
   }

   if (num_partitions_percent_unspecified > 0)
   {
      per_unspec_partition_percent_alloc = 
          (total_pref_percent_size_alloc - sum_pref_sizes) /
          num_partitions_percent_unspecified;

      if (per_unspec_partition_percent_alloc <= 0)
      {
         printf( "ERROR Remaining %s too small\n",
                 "size percentage allocation" );
         return 1;
      }
   }

   /* printf( "DEBUG per_unspec_partition_percent_alloc: %d\n",
           per_unspec_partition_percent_alloc ); */

   if (num_partitions_percent_unspecified > 0)
   {
      int idx2                    = 0;
      int remaining_percent_alloc = total_pref_percent_size_alloc -
                                    sum_pref_sizes;
      int curr_num_partitions_percent_unspecified =
          num_partitions_percent_unspecified;

      for (idx2 = 1; idx2 <= num_partitions; idx2++)
      {
         if (part_pref_size_percent[idx2] < 0)
         {
            curr_num_partitions_percent_unspecified--;

            def_part_pref_size_percent[idx2] = 1;

            if (curr_num_partitions_percent_unspecified > 0)
            {
               part_pref_size_percent[idx2] =
                  per_unspec_partition_percent_alloc;
               remaining_percent_alloc -=
                  per_unspec_partition_percent_alloc;
            }
            else
            {
               part_pref_size_percent[idx2] = remaining_percent_alloc;
            }
         }
      }
   }
   

   /* If we get to an OK status, output various optional messages. */

   printf( "OK\n" );

   printf( "Total Device Size is %d MB\n", total_dev_size_mb );
   printf( "Total Device Size (in cylinders) is %d\n",
           total_dev_size_cyls );

   if (def_pref_percent_size_alloc)
   {
      printf( "Total Preferred Size Percentage Allocation for device ");
      printf( "was unspecified,  so was set to %d %%\n",
              total_pref_percent_size_alloc );
   }
   else
      printf( "%s for device is %d %%\n",
              "Total Preferred Size Percentage Allocation",
              total_pref_percent_size_alloc );

   printf( "Number of partitions is %d\n", num_partitions );

   for (idx = 1; idx <= num_partitions; idx++)
   {
      if (def_part_pref_size_percent[idx])
      {
         printf( "Partition %d preferred size percentage unspecified,",
                 idx );
         printf( " was set to %d %%\n", part_pref_size_percent[idx] );
      }
      else
         printf( "Partition %d preferred size percentage is %d %%\n",
                 idx, part_pref_size_percent[idx] );

      if (def_part_min_size[idx])
         printf( "Partition %d %s %d MB\n",
                 idx, "minimum size unspecified, was set to",
                 part_min_size[idx] );
      else
         printf( "Partition %d minimum size is %d MB\n",
                 idx, part_min_size[idx] );
   }

   printf( "Calculating actual space allocation...\n" );

   for (idx = 1; idx <= num_partitions; idx++)
   { 
      /* Find all partitions that have
         min_size > preferred_size_percent converted to MB */

      int part_preferred_size_mb = part_pref_size_percent[idx] *
                                   total_dev_size_mb / 100;

      /* printf( "DEBUG Preferred size mb for part %d is %d MB\n",
              idx, part_preferred_size_mb ); */

      if (part_min_size[idx] > part_preferred_size_mb)
      {
         printf( "Partition %d minimum size is larger than the ", idx );
         printf( "preferred %% allocation\n" );
         part_actual_size_mb[idx] = part_min_size[idx];
      }
   }

   /* Calculate the total remaining space to be allocated
      and the total size percentages to be allocated */

   {
      int remaining_mb_toalloc       = dev_percent_size_mb;
      int curr_remaining_mb_toalloc  = 0;
      int remaining_percents_toalloc = 0;
      int num_nonset_partitions      = 0;

      for (idx = 1; idx <= num_partitions; idx++)
        if (part_actual_size_mb[idx] > 0)
        {
           remaining_mb_toalloc -= part_actual_size_mb[idx];
        }
        else
        {
           num_nonset_partitions++;
           remaining_percents_toalloc += part_pref_size_percent[idx];
        }

      /* printf( "DEBUG remaining_mb_toalloc is %d\n",
                 remaining_mb_toalloc );
         printf( "DEBUG num_nonset_partitions is %d\n",
                 num_nonset_partitions );
         printf( "DEBUG remaining_percents_toalloc is %d\n",
                 remaining_percents_toalloc );
      */

      curr_remaining_mb_toalloc = remaining_mb_toalloc;

      for (idx = 1; idx <= num_partitions; idx++)
         if (part_actual_size_mb[idx] < 0)
         {
            num_nonset_partitions--;

            if (num_nonset_partitions > 0)
            {
               part_actual_size_mb[idx] = remaining_mb_toalloc        *
                                          part_pref_size_percent[idx] /
                                          remaining_percents_toalloc;

               /* printf( "DEBUG for part %d, calc actual size mb,\n",
                          idx );
                  printf( "DEBUG %s=%d, %s=%d, %s=%d\n",
                          "remaining_mb_toalloc", remaining_mb_toalloc,
                          "part_pref_size_percent",
                          part_pref_size_percent[idx],
                          "remaining_percents_toalloc",
                          remaining_percents_toalloc );
                */
       
               curr_remaining_mb_toalloc -= part_actual_size_mb[idx];
            }
            else
            {
               part_actual_size_mb[idx] = curr_remaining_mb_toalloc;
            }

            /* printf( "DEBUG part %d actual size mb = %d\n",
                    idx, part_actual_size_mb[idx] );  */
         }
   }

   {
      int remaining_cyls = total_dev_size_cyls *
                           total_pref_percent_size_alloc / 100;

      for (idx = 1; idx <= num_partitions; idx++)
      {
         if (idx != num_partitions)
         {
            part_actual_size_cyls[idx] = part_actual_size_mb[idx] *
                                         total_dev_size_cyls /
                                         total_dev_size_mb;
            remaining_cyls -= part_actual_size_cyls[idx];
         }
         else part_actual_size_cyls[idx] = remaining_cyls;
      }
   }

   printf( "Space calculation results:\n" );

   for (idx = 1; idx <= num_partitions; idx++)
   {
      printf( "Partition %d size is %d MB, %d cylinders\n",
              idx, part_actual_size_mb[idx],
                   part_actual_size_cyls[idx] );
   }

   for (idx = 1; idx <= num_partitions; idx++)
   {
      printf( "OUTPUT %d %d %d\n",
              idx, part_actual_size_mb[idx],
                   part_actual_size_cyls[idx] );
   }

   return 0;
}
