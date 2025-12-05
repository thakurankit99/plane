import type { AxiosRequestConfig } from "axios";
import axios from "axios";
// services
import { APIService } from "@/services/api.service";

export class FileUploadService extends APIService {
  private cancelSource: any;

  constructor() {
    super("");
  }

  async uploadFile(
    url: string,
    data: FormData,
    uploadProgressHandler?: AxiosRequestConfig["onUploadProgress"]
  ): Promise<void> {
    this.cancelSource = axios.CancelToken.source();
    
    // Check if this is a PUT upload (R2/S3 presigned URL) or POST upload (legacy)
    // If FormData has no fields except 'file', it's a PUT upload
    const file = data.get('file') as File;
    const isPutUpload = file && Array.from(data.keys()).length === 1;
    
    if (isPutUpload) {
      // Use PUT for R2/S3 presigned URLs
      return this.put(url, file, {
        headers: {
          "Content-Type": file.type,
        },
        cancelToken: this.cancelSource.token,
        withCredentials: false,
        onUploadProgress: uploadProgressHandler,
      })
        .then((response) => response?.data)
        .catch((error) => {
          if (axios.isCancel(error)) {
            console.log(error.message);
          } else {
            throw error?.response?.data;
          }
        });
    } else {
      // Use POST for legacy multipart/form-data uploads
      return this.post(url, data, {
        headers: {
          "Content-Type": "multipart/form-data",
        },
        cancelToken: this.cancelSource.token,
        withCredentials: false,
        onUploadProgress: uploadProgressHandler,
      })
        .then((response) => response?.data)
        .catch((error) => {
          if (axios.isCancel(error)) {
            console.log(error.message);
          } else {
            throw error?.response?.data;
          }
        });
    }
  }

  cancelUpload() {
    this.cancelSource.cancel("Upload canceled");
  }
}
